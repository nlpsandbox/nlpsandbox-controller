#!/usr/bin/env cwl-runner
#
# Workflow for SC1
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []

steps:

  set_submitter_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      # Must update the principal id here
      - id: principalid
        valueFrom: "3379097"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  set_admin_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#adminUploadSynId"
      # Must update the principal id here
      - id: principalid
        valueFrom: "3379097"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  get_docker_submission:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: docker_repository
      - id: docker_digest
      - id: entity_id
      - id: entity_type
      - id: results

  get_docker_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/get_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out: 
      - id: docker_registry
      - id: docker_authentication

  validate_docker:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/validate_docker.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  docker_validation_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate_docker/status"
      - id: invalid_reasons
        source: "#validate_docker/invalid_reasons"
      - id: errors_only
        default: true
    out: [finished]

  annotate_docker_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  check_docker_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate_docker/status"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
      - id: previous_email_finished
        source: "#docker_validation_email/finished"
    out: [finished]

  get_clinical_notes:
    run: get_clinical_notes.cwl
    in:
      - id: docker_script
        default:
          class: File
          location: "get_clinical_notes.py"
      - id: data_endpoint
        valueFrom: "http://10.23.55.45:8080/api/v1"
      - id: output
        valueFrom: "notes.json"
      - id: dataset_id
        valueFrom: "2014-i2b2-20201203"
      - id: fhir_store_id
        valueFrom: "evaluation"
    out:
      - id: notes

  start_service:
    run: start_service.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#check_docker_status/finished"
      - id: docker_script
        default:
          class: File
          location: "start_service.py"
    out:
      - id: finished

  validate_service:
    run: validate_service.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: status
        source: "#start_service/finished"
      - id: synapse_config
        source: "#synapseConfig"
      - id: docker_script
        default:
          class: File
          location: "validate_service.py"
    out:
      - id: finished
      - id: results
      - id: status
      - id: invalid_reasons
# Add annotation and emailing
  check_status_validate_service:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate_service/status"
      - id: previous_annotation_finished
        source: "#validate_service/finished"
    out: [finished]

  annotate_note:
    run: annotate_note.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: status
        source: "#check_status_validate_service/finished"
      - id: synapse_config
        source: "#synapseConfig"
      - id: data_notes
        source: "#get_clinical_notes/notes"
      - id: docker_script
        default:
          class: File
          location: "annotate_note.py"
    out:
      - id: predictions

  upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/upload_to_synapse.cwl
    in:
      - id: infile
        source: "#annotate_note/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#get_docker_submission/entity_id"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results

  annotate_docker_upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#upload_results/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
    out: [finished]

#   validation:
#     run: validate.cwl
#     in:
#       - id: inputfile
#         source: "#run_docker/predictions"
#       - id: entity_type
#         source: "#get_docker_submission/entity_type"
#     out:
#       - id: results
#       - id: status
#       - id: invalid_reasons
  
#   validation_email:
#     run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/validate_email.cwl
#     in:
#       - id: submissionid
#         source: "#submissionId"
#       - id: synapse_config
#         source: "#synapseConfig"
#       - id: status
#         source: "#validation/status"
#       - id: invalid_reasons
#         source: "#validation/invalid_reasons"
#       - id: errors_only
#         default: true
#     out: [finished]

#   annotate_validation_with_output:
#     run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/annotate_submission.cwl
#     in:
#       - id: submissionid
#         source: "#submissionId"
#       - id: annotation_values
#         source: "#validation/results"
#       - id: to_public
#         default: true
#       - id: force
#         default: true
#       - id: synapse_config
#         source: "#synapseConfig"
#       - id: previous_annotation_finished
#         source: "#annotate_docker_upload_results/finished"
#     out: [finished]

#   check_status:
#     run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/check_status.cwl
#     in:
#       - id: status
#         source: "#validation/status"
#       - id: previous_annotation_finished
#         source: "#annotate_validation_with_output/finished"
#       - id: previous_email_finished
#         source: "#validation_email/finished"
#     out: [finished]

#   scoring:
#     run: score.cwl
#     in:
#       - id: inputfile
#         source: "#run_docker/predictions"
#       - id: goldstandard
#         source: "#download_goldstandard/filepath"
#       - id: check_validation_finished 
#         source: "#check_status/finished"
#     out:
#       - id: results
      
#   score_email:
#     run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/score_email.cwl
#     in:
#       - id: submissionid
#         source: "#submissionId"
#       - id: synapse_config
#         source: "#synapseConfig"
#       - id: results
#         source: "#scoring/results"
#     out: []

#   annotate_submission_with_output:
#     run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/annotate_submission.cwl
#     in:
#       - id: submissionid
#         source: "#submissionId"
#       - id: annotation_values
#         source: "#scoring/results"
#       - id: to_public
#         default: true
#       - id: force
#         default: true
#       - id: synapse_config
#         source: "#synapseConfig"
#       - id: previous_annotation_finished
#         source: "#annotate_validation_with_output/finished"
#     out: [finished]
