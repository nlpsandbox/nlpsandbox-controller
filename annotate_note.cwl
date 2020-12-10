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
  - id: parentid
    type: string
  - id: status
    type: boolean?
  - id: synapse_config
    type: File
  - id: data_notes
    type: File
  - id: docker_script
    type: File
  - id: annotator_type
    type: string

arguments: 
  - valueFrom: $(inputs.docker_script.path)
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.data_notes)
    prefix: -i
  - valueFrom: $(inputs.annotator_type)
    prefix: -a

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.docker_script)
  - class: InlineJavascriptRequirement

outputs:
  predictions:
    type: File
    outputBinding:
      glob: predictions.json
