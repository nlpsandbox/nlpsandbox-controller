#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

hints:
  DockerRequirement:
    dockerPull: python:3.7

inputs:
  - id: inputfile
    type: File
  - id: goldstandard
    type: File
  - id: check_validation_finished
    type: boolean?

arguments:
  - valueFrom: score.py
  - valueFrom: $(inputs.inputfile.path)
    prefix: -f
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: score.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json
          parser = argparse.ArgumentParser()
          parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
          parser.add_argument("-r", "--results", required=True, help="Scoring results")
          parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

          args = parser.parse_args()
          score = 3
          prediction_file_status = "SCORED"
          # secondary_metric and secondary_metric_value are optional
          result = {'primary_metric': 'auc',
                    'primary_metric_value': 0.8,
                    'secondary_metric': 'aupr',
                    'secondary_metric_value: 0.2,
                    'submission_status': prediction_file_status}
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))
     
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json

  - id: primary_metric
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['primary_metric'])

  - id: primary_metric_value
    type: double
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['primary_metric_value'])

  - id: secondary_metric
    type: string?
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['secondary_metric'])

  - id: secondary_metric_value
    type: double?
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['secondary_metric_value'])

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_status'])
