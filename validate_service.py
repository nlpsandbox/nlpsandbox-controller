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

    print("Get submission container")
    # Get container
    container = client.containers.get(str(args.submissionid))
    # docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name
    container_ip = container.attrs['NetworkSettings'][
        'Networks'
    ]['submission']['IPAddress']

    exec_cmd = ["curl", "-L", "-X", "GET", f"http://{container_ip}:8080"]
    runtime = client.containers.run("curlimages/curl:7.73.0", exec_cmd,
                                    name=f"{args.submissionid}_curl",
                                    network="submission", stderr=True,
                                    auto_remove=True)
    print(runtime)
    print("finished")
    invalid_reasons = ""
    prediction_file_status = ""

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
