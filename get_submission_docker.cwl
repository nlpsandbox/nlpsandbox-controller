#!/usr/bin/env cwl-runner
#
# Extract the submitted Docker repository and Docker digest
# And submitterSynid and adminUploadSynId
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.2.2

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File

arguments:
  - valueFrom: get_submission_docker.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: results.json
    prefix: -r
  - valueFrom: output.json
    prefix: -o
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: get_submission_docker.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-r", "--results", required=True, help="download results info")
          parser.add_argument("-o", "--output", required=True, help="download results info")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          sub = syn.getSubmission(args.submissionid, downloadLocation=".")

          if sub.entity.concreteType!='org.sagebionetworks.repo.model.docker.DockerRepository':
            raise Exception('Expected DockerRepository type but found '+sub.entity.concreteType)
          result = {'docker_repository': sub.get("dockerRepositoryName",""),
                    'docker_digest': sub.get("dockerDigest",""),
                    'entityid': sub.entity.id}
          status = syn.getSubmissionStatus(args.submissionid)
          get_values = filter(lambda x: x.get('key') in ['admin_folder', 'orgSagebionetworksSynapseWorkflowOrchestratorSubmissionFolder'],
                              status.annotations['stringAnnos'])
          add_values = {value['key']: value['value'] for value in get_values}
          # Just for testing purposes - if all the steps work, this annotations
          # should exist
          if add_values.get("admin_folder") is None:
            add_values['admin_folder'] = ''
          if add_values.get("orgSagebionetworksSynapseWorkflowOrchestratorSubmissionFolder") is None:
            add_values['orgSagebionetworksSynapseWorkflowOrchestratorSubmissionFolder'] = ''
          result.update(add_values)
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))

          submitterid = sub['userId'] if sub.get("teamId") is None else sub['teamId'] 
          userids = {'main_userid': sub.userId, 'main_submitterId': submitterid}
          with open(args.output, 'w') as o:
            o.write(json.dumps(userids))

outputs:
  - id: docker_repository
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['docker_repository'])
  - id: docker_digest
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['docker_digest'])
  - id: entity_id
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['entityid'])
  - id: admin_synid
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['admin_folder'])
  - id: submitter_synid
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['orgSagebionetworksSynapseWorkflowOrchestratorSubmissionFolder'])
  - id: results
    type: File
    outputBinding:
      glob: output.json
