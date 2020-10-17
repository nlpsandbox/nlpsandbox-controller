"""Run training synthetic docker models"""
import argparse
import getpass
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


def main(args):
    """Run docker model"""
    if args.status == "INVALID":
        raise Exception("Docker image is invalid")

    client = docker.from_env()

    print(getpass.getuser())

    # Add docker.config file
    docker_image = "nlpsandbox/cli:edge"

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

    container = client.containers.run(
        docker_image,
        "community get-clinical-notes --output /output/notes.json",
        volumes=volumes, mem_limit='6g', stderr=True
    )

    remove_docker_container(container.name)

    # output_folder = os.listdir(output_dir)

    # CWL has a limit of the array of files it can accept in a folder
    # therefore creating a tarball is sometimes necessary
    # tar(output_dir, 'outputs.tar.gz')




if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("-e", "--data_endpoint")
    args = parser.parse_args()
    main(args)
