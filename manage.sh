#!/bin/bash

set -e

echo "=>Sourcing..."
source setenv.sourceme


set_host_default () {   
	echo "=>docker-machine env ${DOCKER_HOST_NAME}"
	eval "$(docker-machine env ${DOCKER_HOST_NAME})"
}

print_usage(){
	echo "Usage: manage.sh [up | down | deploy ]"
}

init(){
	echo "==>Init"
	IMAGE_TAG="1"
	INAME="jupyter"
	IMAGE="${INAME}_i"
	CONTAINER="${INAME}_c"
	REMOTE_IMAGE=${DOCKER_HUB_USER}/${IMAGE}	
	TAGGED_IMAGE=${REMOTE_IMAGE}:${IMAGE_TAG}
}


build_image(){		
	init	
	echo "==>Building image ${TAGGED_IMAGE}..."	
	docker build -t ${TAGGED_IMAGE} .			
}

start_container(){	
	echo "==>Starting container ${CONTAINER}..."	
	docker stop ${CONTAINER} &>/dev/null || true
	docker rm ${CONTAINER} &>/dev/null || true	
	docker run -d -p 8888:8888 -v /${ROOT_VOLUME_MOUNT_DIR}/data:/home/docker/data --name ${CONTAINER} ${TAGGED_IMAGE}	
}


#Main logic
start=`date +%s`

case $1 in 


    up)
        echo "=>Up..."

		DOCKER_HOST_NAME=${APP_NAME}-${DOCKER_VBOX_DRIVER}

		set +e
		# check if host exists
		echo "checking if ${DOCKER_HOST_NAME} exists..."
		docker-machine inspect ${DOCKER_HOST_NAME} >/dev/null
		if [[ $? -eq 0 ]]; then
			echo "Host already exists, exiting."
			exit 0
		fi 
		set -e

		echo "=>creating machine ${DOCKER_HOST_NAME} for driver virtualbox..."
		docker-machine create --driver ${DOCKER_VBOX_DRIVER} --virtualbox-cpu-count 2 --virtualbox-memory "6000" --virtualbox-disk-size "30000" ${DOCKER_HOST_NAME}
		DOCKER_IP=$(docker-machine ip ${DOCKER_HOST_NAME})
		docker-machine ssh ${DOCKER_HOST_NAME} "sudo sysctl -w vm.max_map_count=262144"
		
		echo "=>setting default host..."
		set_host_default 				
		
		echo "=>Building image..."
		build_image

		echo "=>Starting container..."
		start_container
		
		echo "=>Access at ${DOCKER_IP}" 
		
        ;;
		
    down)        
        echo "=>Down..."
		DOCKER_HOST_NAME=${APP_NAME}-${DOCKER_VBOX_DRIVER}
		docker-machine rm -f ${DOCKER_HOST_NAME}					
        ;;
		
    deploy)

		echo "=>Deploy..."
		
		DOCKER_HOST_NAME=${APP_NAME}-${DOCKER_VBOX_DRIVER}
		DOCKER_IP=$(docker-machine ip ${DOCKER_HOST_NAME})		
		docker-machine ssh ${DOCKER_HOST_NAME} "sudo sysctl -w vm.max_map_count=262144"
		
		echo "=>setting default host..."
		set_host_default 				
		
		echo "=>Building image..."
		build_image
		
		echo "=>Starting container..."
		start_container
		
		echo "=>Access at ${DOCKER_IP}" 				
		;;
		
	test)
		;;
	
    *)
		print_usage
        exit 1
		
esac

end=`date +%s`
runtime=$((end-start))
echo "Script running time: ${runtime} seconds"
