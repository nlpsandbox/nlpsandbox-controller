#!/usr/bin/env cwl-runner
#
# Extract the submitted Docker repository and Docker digest
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.3.0

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File

arguments:
  - valueFrom: get_linked_submissionid.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: get_linked_submissionid.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          sub = syn.getSubmission(args.submissionid, downloadLocation=".")

          evaluation_dict = {"evaluation_id": sub.evaluationId}
          with open("results.json", 'w') as json_file:
            json_file.write(json.dumps(evaluation_dict))

outputs:
  - id: submissionid
    type: int
    outputBinding:
      # This tool depends on the submission.json to be named submission.json
      glob: submission.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submissionid'])

  - id: evaluation_id
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['evaluation_id'])

  - id: results
    type: File
    outputBinding:
      glob: results.json
