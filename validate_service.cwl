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

arguments: 
  - valueFrom: $(inputs.docker_script.path)
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r

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
