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
  - id: api_version
    type: string
    default: "1.0.2"
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

  get_submissionid:
    run: get_linked_submissionid.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: submissionid
      - id: evaluation_id
      - id: results

  get_evaluation_config:
    run: get_config.cwl
    in:
      - id: queue_id
        source: "#get_submissionid/evaluation_id"
      - id: configuration
        default:
          class: File
          location: "config.yml"
    out:
      - id: submit_to_queue
      - id: config
      - id: dataset_id
      - id: center

  modify_config_annotations:
    run: modify_annotations.cwl
    in:
      - id: inputjson
        source: "#get_evaluation_config/config"
      - id: site
        source: "#get_evaluation_config/center"
    out: [results]

  annotate_main_submission_with_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: annotation_values
        source: "#modify_config_annotations/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  annotate_internal_submission:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#get_evaluation_config/config"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  set_submitter_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/set_permissions.cwl
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

  get_docker_submission:
    run: get_submission_docker.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: docker_repository
      - id: docker_digest
      - id: entity_id
      - id: results
      - id: admin_synid
      - id: submitter_synid
      - id: evaluation_id

  get_docker_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/get_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: docker_registry
      - id: docker_authentication

  annotate_submission_main_submitter:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#get_docker_submission/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  list_clinical_notes:
    run: list_notes.cwl
    in:
      - id: data_endpoint
        valueFrom: "http://10.23.54.142/api/v1/"
      - id: output
        valueFrom: "notes.json"
      - id: dataset_id
        source: "#get_evaluation_config/dataset_id"
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
      # - id: status
      #   source: "#check_docker_status/finished"
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

  annotate_note:
    run: annotate_note.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: parentid
        source: "#submitterUploadSynId"
      # - id: status
      #   source: "#check_status_validate_tool/finished"
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
        source: "#get_evaluation_config/dataset_id"
      - id: annotation_store_id
        source: "#make_store_name/annotation_store_id"
      - id: annotation_json
        source: "#annotate_note/predictions"
    out: []

  download_goldstandard:
    run: list_annotations.cwl
    in:
      - id: data_endpoint
        valueFrom: "http://10.23.54.142/api/v1/"
      - id: output
        valueFrom: "goldstandard.json"
      - id: dataset_id
        source: "#get_evaluation_config/dataset_id"
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
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#convert_score/results"
    out: []

  modify_score_annotations:
    run: modify_annotations.cwl
    in:
      - id: inputjson
        source: "#convert_score/results"
      - id: site
        source: "#get_evaluation_config/center"
    out: [results]

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
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
        source: "#annotate_submission_main_submitter/finished"
    out: [finished]

  annotate_main_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: annotation_values
        source: "#modify_score_annotations/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_submission_with_output/finished"
    out: [finished]
