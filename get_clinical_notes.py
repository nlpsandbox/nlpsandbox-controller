"""Getting all the clinical notes"""
import argparse
import getpass
import os
import random
import string

import docker


def get_random_string(length):
    """Get random string"""
    letters = string.ascii_lowercase
    result_str = ''.join(random.choice(letters) for i in range(length))
    return result_str


def remove_docker_container(container_name):
    """Remove docker container"""
    client = docker.from_env()
    try:
        cont = client.containers.get(container_name)
        cont.stop()
        cont.remove()
    except Exception:
        print("Unable to remove container")


def main(args):
    """Get clinical notes"""
    client = docker.from_env()

    print(getpass.getuser())

    # Add docker.config file
    # docker_image = "nlpsandbox/cli:edge"
    docker_image = "test:latest"

    # These are the volumes that you want to mount onto your docker container
    output_dir = os.getcwd()

    # These are the locations on the docker that you want your mounted
    # volumes to be + permissions in docker (ro, rw)
    # It has to be in this format '/output:rw'
    mounted_volumes = {output_dir: '/output:rw'}
    # All mounted volumes here in a list
    all_volumes = [output_dir]
    # Mount volumes
    volumes = {}
    for vol in all_volumes:
        volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0],
                        'mode': mounted_volumes[vol].split(":")[1]}

    # If the container doesn't exist, make sure to run the docker image
    name = get_random_string(8)
    logs = client.containers.run(
        docker_image,
        f"community get-clinical-notes --output /output/{args.output}",
        name=name,
        auto_remove=True
    )
    print(logs)
    remove_docker_container(name)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("-e", "--data_endpoint")
    args = parser.parse_args()
    main(args)
