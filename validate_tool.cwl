#!/usr/bin/env cwl-runner
#
# Annotates clinical note
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: status
    type: boolean?
  - id: docker_script
    type: File
  - id: annotator_type
    type: string
  - id: subset_data
    type: File
  - id: schema_version
    type: string

arguments:
  - valueFrom: $(inputs.docker_script.path)
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.annotator_type)
    prefix: -a
  - valueFrom: $(inputs.subset_data)
    prefix: --subset_data
  - valueFrom: $(inputs.schema_version)
    prefix: --schema_version

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.docker_script)
  - class: InlineJavascriptRequirement

outputs:
  finished:
    type: boolean
    outputBinding:
      outputEval: $( true )

  results:
    type: File
    outputBinding:
      glob: results.json

  status:
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_status'])

  invalid_reasons:
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_errors'])
