#!/usr/bin/env cwl-runner
#
# Convert table to json
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.3.1

inputs:
  - id: synapse_config
    type: File

arguments:
  - valueFrom: table_to_json.py
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: table_to_json.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json
          import os

          import synapseclient

          parser = argparse.ArgumentParser()
          parser.add_argument("-r", "--results", required=True, help="download results info")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          queue_mapping_table = syn.tableQuery("select * from syn25952454")
          queue_mappingdf = queue_mapping_table.asDataFrame()
          queue_mappingdf.index = queue_mappingdf['queue_id']
          queue_mappingdf['dataset_version'] = queue_mappingdf['dataset_version'].astype(str)
          config = queue_mappingdf.to_dict("index")
          with open(args.results, 'w') as o:
            o.write(json.dumps(config))

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
