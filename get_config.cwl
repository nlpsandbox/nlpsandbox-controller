#!/usr/bin/env cwl-runner
#
# Get more configuration of evaluation queues
# Converts yaml 2 json
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [python3, get_config.py]

hints:
  DockerRequirement:
    dockerPull: biowdl/pyyaml:3.13-py37-slim

requirements:
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: get_config.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json

          import yaml

          parser = argparse.ArgumentParser()
          parser.add_argument("-c", "--config", required=True, help="Configuration file")
          parser.add_argument("-q", "--queue", required=True, type=int, help="The ID of a queue")
          parser.add_argument("-r", "--results", required=True, help="The ID of a queue")

          args = parser.parse_args()

          with open(args.config) as yaml_file:
            config = yaml.load(yaml_file)

          with open(args.results, 'w') as json_file:
            json_file.write(json.dumps(config[args.queue]))

inputs:
  - id: configuration
    type: File
    inputBinding:
      position: 1
      prefix: -c

  - id: queue_id
    type: string
    inputBinding:
      prefix: -q

  - id: results
    type: string
    default: "config.json"
    inputBinding:
      prefix: -r

outputs:

  - id: submit_to_queue
    type: string[]?
    outputBinding:
      glob: $(inputs.results)
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submit_to'])

  - id: dataset_name
    type: string
    outputBinding:
      glob: $(inputs.results)
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['dataset_name'])

  - id: dataset_version
    type: string
    outputBinding:
      glob: $(inputs.results)
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['dataset_version'])

  - id: runtime
    type: int
    outputBinding:
      glob: $(inputs.results)
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['runtime'])

  - id: center
    type: string
    outputBinding:
      glob: $(inputs.results)
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['center'])

  - id: config
    type: File
    outputBinding:
      glob: $(inputs.results)

  - id: dataset_id
    type: string
    outputBinding:
      glob: $(inputs.results)
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['dataset_name'])-$(JSON.parse(self[0].contents)['dataset_version'])
