#!/usr/bin/env cwl-runner
#
# Switches subchallenge 2 annotations with subchallenge 3 annotations
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.3.0

inputs:
  - id: inputjson
    type: File
  - id: site
    type: string

arguments:
  - valueFrom: switch_annotation.py
  - valueFrom: $(inputs.inputjson.path)
    prefix: -j
  - valueFrom: $(inputs.site)
    prefix: -s
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: switch_annotation.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import json
          parser = argparse.ArgumentParser()
          parser.add_argument("-j", "--json", required=True, help="Json input to switch")
          parser.add_argument("-s", "--site", required=True, help="Center")
          parser.add_argument("-r", "--results", required=True, help="Switched json")
          args = parser.parse_args()
          
          with open(args.json, "r") as input:
            result = json.load(input)

          exclude_annotations = ("site", "goldstandard", "question",
                                 "runtime", "volume")
          new_score = {f'{args.site}_{key}': value
                       for key, value in result.items()
                       if not key.endswith(exclude_annotations)}
          with open(args.results, 'w') as o:
            o.write(json.dumps(new_score))
     
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json