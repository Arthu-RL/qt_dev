import argparse
import subprocess as sp
import logging as log
import os

from typing import Dict, Optional

log.basicConfig(level=log.INFO, format='%(levelname)s: %(message)s')


def parse_build_args(build_args: str) -> Dict[str, str]:
    build_args_dict: Dict[str, str] = {}
    args_list = build_args.split()

    for arg in args_list:
        key, value = arg.split('=')
        build_args_dict.update({key: value})
    
    return build_args_dict

def build(image: str, dockerfile: str, build_args: Optional[str], retry: int) -> None:
    build_args_cmd: str = ""
    if build_args:
        build_args_dict = parse_build_args(build_args)
        for key, value in build_args_dict.items():
            build_args_cmd += f"--build-arg {key.upper()}=\"{value}\" "

    build_command: str = f"docker build {build_args_cmd} -t {image} -f {dockerfile} .".strip()

    log.info(f"Running build command: {build_command}")

    for _ in range(retry):
        try:
            result = sp.run(build_command, shell=True, check=True, capture_output=True, text=True)
            log.info(f"Build output:\n{result.stderr}")

            break
        except sp.CalledProcessError as e:
            log.error(f"Build failed with error:\n{e.stderr}")

def run(project_path: str, image: str, container_name: str) -> None:
    run_command = f"""
        docker rm -f {container_name} && \
        docker run --gpus all --runtime=nvidia --privileged -d --name {container_name} \
            --ipc=host \
            -e NVIDIA_VISIBLE_DEVICES=all \
            -e NVIDIA_DRIVER_CAPABILITIES=all \
            -e DISPLAY=$DISPLAY \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
            -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
            -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY \
            -v {project_path}:/workspace \
            -v {project_path}/qtcreator_config:/root/.config/QtProject \
            -w /workspace \
            {image}
    """.strip()

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
parser.add_argument('--build', dest='build', action='store_true', help='Build docker image', required=False)
parser.add_argument('-r', '--retry', dest='retry', type=int, help='Build docker image', required=False, default=1)
parser.add_argument('--base', dest='base', action='store_true', help='Build docker image Base/Derived', required=False)
parser.add_argument('--push', dest='push', action='store_true', help='Push image to dockerhub after building', required=False)
parser.add_argument('-p', '--project_path', dest='project_path', type=str, help='Path to the project', default=f"{os.getenv('HOME')}/dev")
parser.add_argument('-ir', '--image_repo', dest='image_repo', type=str, help='Tag of the dev image', default='arthurrl')
parser.add_argument('-in', '--image_name', dest='image_name', type=str, help='Name of the dev image', default='vulkan-dev')
parser.add_argument('-it', '--image_tag', dest='image_tag', type=str, help='Tag of the dev image', default='latest')
parser.add_argument('-c', '--container_name', dest='container_name', type=str, help='Name of the dev container', default='vulkan-dev')
parser.add_argument('-ba', '--build_args', dest='build_args', type=str, help="Docker Build args container passed in StringList formatter sep=' '", default=None)

args: argparse.Namespace = parser.parse_args()

if not os.path.isdir(args.project_path):
    os.makedirs(args.project_path, exist_ok=True)

if not (len(args.image_name) > 0):
    log.error(f"image_name parameter required!")
    parser.print_help()
    exit(1)

image: str = f"{args.image_repo}/{args.image_name}:{args.image_tag}"
image = image.removeprefix('/')

if args.build:
    build(image=image, dockerfile='Dockerfile.base' if args.base else 'Dockerfile', build_args=args.build_args, retry=args.retry)

if args.run:
    run(project_path=args.project_path, image=image, container_name=args.container_name)

if args.push:
    push(image=image)