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
  - id: dataset_name
    type: string
    default: "2014-i2b2"
  - id: dataset_version
    type: string
    default: "20201203"
  - id: api_version
    type: string
    default: "1.0.1"
  - id: fhir_store_id
    type: string
    #default: "awesome-fhir-store"
    default: "evaluation"


# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []
# outputs:
#  result:
#    type: File
#    outputSource: scoring/results

steps:

  create_annotations_json:
    run: create_dataset_annotation.cwl
    in:
      - id: dataset_name
        source: "#dataset_name"
      - id: dataset_version
        source: "#dataset_version"
      - id: api_version
        source: "#api_version"
    out: [json_out, dataset_id]

  annotate_dataset_version:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#create_annotations_json/json_out"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  set_submitter_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        valueFrom: "3413389"
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
      - id: principalid
        valueFrom: "3413389"
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
      - id: evaluation_id

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
      - id: previous_annotation_finished
        source: "#annotate_dataset_version/finished"
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

  list_clinical_notes:
    run: list_notes.cwl
    in:
      - id: data_endpoint
        valueFrom: "http://10.23.54.142/api/v1/"
      - id: output
        valueFrom: "notes.json"
      - id: dataset_id
        source: "#create_annotations_json/dataset_id"
      - id: fhir_store_id
        source: "#fhir_store_id"
    out:
      - id: notes

  list_subset_clinical_notes:
    run: list_notes.cwl
    in:
      - id: data_endpoint
        valueFrom: "http://10.23.54.142/api/v1/"
      - id: output
        valueFrom: "notes.json"
      - id: dataset_id
        valueFrom: "2014-i2b2-20201203-subset"
      - id: fhir_store_id
        source: "#fhir_store_id"
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

  determine_annotator_type:
    run: determine_annotator_type.cwl
    in:
      - id: queue
        source: "#get_docker_submission/evaluation_id"
    out: [annotator_type]

  validate_tool:
    run: validate_tool.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: schema_version
        source: "#api_version"
      - id: subset_data
        source: "#list_subset_clinical_notes/notes"
      - id: status
        source: "#start_service/finished"
      - id: synapse_config
        source: "#synapseConfig"
      - id: annotator_type
        source: "#determine_annotator_type/annotator_type"
      - id: docker_script
        default:
          class: File
          location: "validate_tool.py"
    out:
      - id: finished
      - id: results
      - id: status
      - id: invalid_reasons

  service_validation_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate_tool/status"
      - id: invalid_reasons
        source: "#validate_tool/invalid_reasons"
      - id: errors_only
        default: true
    out: [finished]

  annotate_service_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_tool/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  check_status_validate_tool:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate_tool/status"
      - id: previous_annotation_finished
        source: "#annotate_service_validation_with_output/finished"
      - id: previous_email_finished
        source: "service_validation_email/finished"
    out: [finished]

  annotate_note:
    run: annotate_note.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: status
        source: "#check_status_validate_tool/finished"
      - id: synapse_config
        source: "#synapseConfig"
      - id: data_notes
        source: "#list_clinical_notes/notes"
      - id: annotator_type
        source: "#determine_annotator_type/annotator_type"
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

  make_store_name:
    run: make_annotation_store_name.cwl
    in:
      - id: submission_id
        source: "#submissionId"
    out: [annotation_store_id]

  store_annotations:
    run: store_annotations.cwl
    in:
      - id: data_endpoint
        valueFrom: "http://10.23.54.142/api/v1/"
      - id: dataset_id
        source: "#create_annotations_json/dataset_id"
      - id: annotation_store_id
        source: "#make_store_name/annotation_store_id"
      - id: annotation_json
        source: "#annotate_note/predictions"
    out: []

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
        source: "#annotate_service_validation_with_output/finished"
    out: [finished]

  download_goldstandard:
    run: list_annotations.cwl
    in:
      - id: data_endpoint
        valueFrom: "http://10.23.54.142/api/v1/"
      - id: output
        valueFrom: "goldstandard.json"
      - id: dataset_id
        source: "#create_annotations_json/dataset_id"
      - id: annotation_store_id
        valueFrom: "goldstandard"
    out:
      - id: annotations

  scoring:
    run: score.cwl
    in:
      - id: pred_filepath
        source: "#annotate_note/predictions"
      - id: gold_filepath
        source: "#download_goldstandard/annotations"
      - id: output
        valueFrom: "result.json"
      - id: eval_type
        source: "#determine_annotator_type/annotator_type"
    out:
      - id: results

  convert_score:
    run: convert_score.cwl
    in:
      - id: score_json
        source: "#scoring/results"
      - id: annotator_type
        source: "#determine_annotator_type/annotator_type"
    out:
      - id: results

  score_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#convert_score/results"
    out: []

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.0/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#convert_score/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_upload_results/finished"
    out: [finished]
