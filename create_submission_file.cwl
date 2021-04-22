#!/usr/bin/env cwl-runner
#
# Create JSON submission file with submission Id
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [ python3, create.py ]

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.3.0

inputs:
  - id: submissionid
    type: int
    inputBinding:
      prefix: -i

  - id: results
    type: string
    default: "submission.json"
    inputBinding:
      prefix: -r

  - id: previous
    type: boolean?

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: create.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json

          parser = argparse.ArgumentParser()
          parser.add_argument("-r", "--results", required=True, help="Scoring results")
          parser.add_argument("-i", "--submissionid", required=True, help="Submission ID")
          args = parser.parse_args()

          submission_dict = {"submissionid": int(args.submissionid)}
          with open(args.results, 'w') as json_file:
            json_file.write(json.dumps(submission_dict))

outputs:
  - id: submission_out
    type: File
    outputBinding:
      glob: submission.json
