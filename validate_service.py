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
    container = client.containers.get(str(args.submissionid))
    # docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name
    container_ip = container.attrs['NetworkSettings'][
        'Networks'
    ]['submission']['IPAddress']

    # TODO: This will have to map to evaluation queue
    api_url_map = {
        'date': "textDateAnnotations",
        'person': "textPersonNameAnnotations",
        'location': "textPhysicalAddressAnnotations"
    }

    exec_cmd = ["curl", "-s", "-L", "-X", "GET",
                f"http://{container_ip}:8080"]
    service = client.containers.run("curlimages/curl:7.73.0", exec_cmd,
                                    name=f"{args.submissionid}_curl",
                                    network="submission", stderr=True,
                                    auto_remove=True)
    # TODO: validate runtime
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
    example_post = client.containers.run(
        "curlimages/curl:7.73.0", exec_cmd,
        name=f"{args.submissionid}_curl",
        network="submission", stderr=True,
        auto_remove=True
    )
    print(example_post)
    # TODO: Validate post response

    print("finished")
    if invalid_reasons:
        prediction_file_status = "VALIDATED"
    else:
        prediction_file_status = "INVALID"

    result = {'submission_errors': "\n".join(invalid_reasons),
              'submission_status': prediction_file_status}
    with open(args.results, 'w') as file_o:
        file_o.write(json.dumps(result))

    # Try to remove the image
    # remove_docker_container(args.submissionid)
    # remove_docker_image(container.image)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("-r", "--results", required=True,
                        help="results file")
    args = parser.parse_args()
    main(args)
