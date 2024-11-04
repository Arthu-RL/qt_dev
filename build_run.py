import argparse
import subprocess as sp
import logging as log
import os

log.basicConfig(level=log.INFO, format='%(levelname)s: %(message)s')

def build(image: str) -> None:
    build_command: str = f"docker build -t {image} -f Dockerfile ."

    log.info(f"Running build command: {build_command}")

    try:
        result = sp.run(build_command, shell=True, check=True, capture_output=True, text=True)
        log.info(f"Build output:\n{result.stderr}")
    except sp.CalledProcessError as e:
        log.error(f"Build failed with error:\n{e.stderr}")
        exit(1)

def run(project_path: str, image: str, container_name: str) -> None:
    run_command = f"""
        docker rm -f {container_name} && \
        docker run --gpus all --privileged -d --name {container_name} \
            -e NVIDIA_VISIBLE_DEVICES=all \
            -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics \
            -e DISPLAY=$DISPLAY \
            -e XDG_RUNTIME_DIR=/tmp/runtime-root \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -v /dev/dri:/dev/dri \
            -v {project_path}:/workspace \
            -v {project_path}/qtcreator_config:/root/.config/QtProject \
            -w /workspace \
            {image}
    """

    log.info(f"Run command:\n{run_command}")

    try:
        result = sp.run(run_command, shell=True, check=True, capture_output=True, text=True)
        log.info(f"Run output:\n{result.stdout}")
    except sp.CalledProcessError as e:
        log.error(f"Run failed with error:\n{e.stderr}")
        exit(1)

def push(image: str) -> None:
    run_command: str = f"""
        docker push {image}
    """

    log.info(f"Run command:\n{run_command}")

    try:
        result = sp.run(run_command, shell=True, check=True, capture_output=True, text=True)
        log.info(f"Push output:\n{result.stdout}")
    except sp.CalledProcessError as e:
        log.error(f"Push failed with error:\n{e.stderr}")
        exit(1)


parser: argparse.ArgumentParser = argparse.ArgumentParser(description="Build Vulkan dev image")

parser.add_argument('--run', dest='run', action='store_true', help='Run container instead of building', required=False)
parser.add_argument('--push', dest='push', action='store_true', help='Push image to dockerhub after building', required=False)
parser.add_argument('-p', '--project_path', dest='project_path', type=str, help='Path to the project', default=f"{os.getenv('HOME')}/dev")
parser.add_argument('-ir', '--image_repo', dest='image_repo', type=str, help='Tag of the dev image', default='arthurrl')
parser.add_argument('-in', '--image_name', dest='image_name', type=str, help='Name of the dev image', default='vulkan_dev')
parser.add_argument('-it', '--image_tag', dest='image_tag', type=str, help='Tag of the dev image', default='latest')
parser.add_argument('-c', '--container_name', dest='container_name', type=str, help='Name of the dev container', default='vulkan-dev')

args: argparse.Namespace = parser.parse_args()

if not os.path.isdir(args.project_path):
    os.makedirs(args.project_path, exist_ok=True)

if not (len(args.image_name) > 0):
    log.error(f"image_name parameter required!")
    exit(1)

image: str = f"{args.image_repo}/{args.image_name}:{args.image_tag}"
image = image.removeprefix('/')

if args.run:
    run(project_path=args.project_path, image=image, container_name=args.container_name)
else:
    build(image=image)

if args.push:
    push(image=image)