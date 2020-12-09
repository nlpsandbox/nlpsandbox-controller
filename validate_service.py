"""Run training synthetic docker models"""
import argparse
import json
import os

import docker


def remove_docker_container(container_name):
    """Remove docker container"""
    client = docker.from_env()
    try:
        cont = client.containers.get(container_name)
        cont.stop()
        cont.remove()
    except Exception:
        print("Unable to remove container")


def remove_docker_image(image_name):
    """Remove docker image"""
    client = docker.from_env()
    try:
        client.images.remove(image_name, force=True)
    except Exception:
        print("Unable to remove image")


def main(args):
    """Run docker model"""
    client = docker.from_env()
    invalid_reasons = []

    print("Get submission container")
    # Get container
    submissionid = args.submissionid
    container = client.containers.get(submissionid)
    # This obtains the ip of each docker container only accesible to other
    # docker containers on the same network
    # docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name
    container_ip = container.attrs['NetworkSettings'][
        'Networks'
    ]['submission']['IPAddress']
    print(container_ip)
    # TODO: This will have to map to evaluation queue
    api_url_map = {
        'date': "textDateAnnotations",
        'person': "textPersonNameAnnotations",
        'location': "textPhysicalAddressAnnotations"
    }
    annotator_client = "test"
    # validate that the root URL redirects to the service API endpoint
    # exec_cmd = ["curl", "-s", "-L", "-X", "GET",
    #             f"http://{container_ip}:8080"]
    exec_cmd = ["evaluate", "get-annotator-service", '--annotator_host', 
                f"http://{container_ip}:8080/api/v1"]
    try:
        # auto_remove doesn't work when being run with the orchestrator
        service = client.containers.run(annotator_client, exec_cmd,
                                        name=f"{args.submissionid}_curl_1",
                                        network="submission", stderr=True)
                                        # auto_remove=True)
        service_info = json.loads(service.decode("utf-8"))
        expected_service_keys = ['author', 'authorEmail', 'description',
                                 'license', 'name', 'repository', 'url',
                                 'version']
        for key in expected_service_keys:
            if key not in service_info.keys():
                invalid_reasons.append(
                    "API service endpoint returns incorrect schema"
                )
            break
    except Exception:
        invalid_reasons.append(
            "API /service endpoint not implemented. "
            "Root URL must also redirect to service endpoint"
        )
    remove_docker_container(f"{args.submissionid}_curl_1")
    # validate that the note can be annotated by particular annotator
    example_note = {
        "note": {
            "noteType": "loinc:LP29684-5",
            "patientId": "507f1f77bcf86cd799439011",
            "text": "On 12/26/2020, Ms. Chloe Price met with Dr. Prescott."
        }
    }
    exec_cmd = [
        "curl", "-s", "-X", "POST",
        f"http://{container_ip}:8080/api/v1/{api_url_map['date']}", "-H",
        "accept: application/json",
        "-H", "Content-Type: application/json", "-d",
        json.dumps(example_note)
    ]
    try:
        example_post = client.containers.run(
            "curlimages/curl:7.73.0", exec_cmd,
            name=f"{args.submissionid}_curl_2",
            network="submission", stderr=True
            # auto_remove=True
        )
    except Exception:
        invalid_reasons.append(
            f"API /{api_url_map['date']} endpoint not implemented. "
        )
    remove_docker_container(f"{args.submissionid}_curl_2")

    print("finished")
    print(invalid_reasons)
    # If there are no invalid reasons -> Validated
    if not invalid_reasons:
        prediction_file_status = "VALIDATED"
    else:
        prediction_file_status = "INVALID"
        # Try to remove the image if the service is invalid
        remove_docker_container(args.submissionid)
        remove_docker_image(container.image)

    result = {'submission_errors': "\n".join(invalid_reasons),
              'submission_status': prediction_file_status}
    with open(args.results, 'w') as file_o:
        file_o.write(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id", type=str)
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("-r", "--results", required=True,
                        help="results file")
    args = parser.parse_args()
    main(args)
