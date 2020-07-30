#!/bin/bash

# at least 1 argument to be pass in
if  [ $# == 0 ]; then
    echo "run.sh needs a service module package to run"
    echo "eg: run.sh gate.service orders.service products.service"
    exit 1
fi

# Setup env if not available
export PYTHONPATH=./gateway:./orders:./products

if [ -n "${AMQP_URI}" ]; then
	echo "Using DEV Environment variables.."
    echo 
else
	echo "Using Production Environment Variables in CF.."

  
    AMQP_HOST=$(echo ${VCAP_SERVICES} | jq -r '.mq[0].credentials.AMQP_ENDPOINTS')
AMQP_PWD=$(echo ${VCAP_SERVICES} | jq -r '.mq[0].credentials.ACTIVE_MQ_PASSWORD')
AMQP_USER=$(echo ${VCAP_SERVICES} | jq -r '.mq[0].credentials.ACTIVE_MQ_USERNAME')

AMQP_URI=`echo $AMQP_HOST | sed "s/:\/\//:\/\/$AMQP_USER:$AMQP_PWD@/g"`



    POSTGRES_HOST=$(echo ${VCAP_SERVICES} | jq -r '.aurorapostgresql[0].credentials.CLUSTER_ENDPOINT')
POSTGRES_PWD=$(echo ${VCAP_SERVICES} | jq -r '.aurorapostgresql[0].credentials.DB_PASSWORD')
POSTGRES_USER=$(echo ${VCAP_SERVICES} | jq -r '.aurorapostgresql[0].credentials.DB_USERNAME')
POSTGRES_DB=$(echo ${VCAP_SERVICES} | jq -r '.aurorapostgresql[0].credentials.DB_NAME')
POSTGRES_PORT=$(echo ${VCAP_SERVICES} | jq -r '.aurorapostgresql[0].credentials.PORT')

POSTGRES_URI=postgres://${POSTGRES_USER}:${POSTGRES_PWD}@${POSTGRES_HOST}:${POSTGRES_PORT}/orders

    REDIS_HOST=$(echo ${VCAP_SERVICES} | jq -r '.elasticache[0].credentials.ENDPOINT_ADDRESS')
    REDIS_PORT=`echo 5439`
#    REDIS_PWD=$(echo ${VCAP_SERVICES} | jq -r '.elasticache[0].credentials.DB_PASSWORD')
    REDIS_URI=${REDIS_HOST}:${REDIS_PORT}

#    echo AMQP = $AMQP_URI 
#    echo POSTGRES = $POSTGRES_URI 
#    echo REDIS = $REDIS_URI

    export AMQP_URI POSTGRES_URI REDIS_URI
fi



# Run Migrations for Postgres DB for Orders' backing service 
(
    cd orders
    PYTHONPATH=. alembic revision --autogenerate -m "init"
    PYTHONPATH=. alembic upgrade head
)


# nameko show-config

if [ -n "${DEBUG}" ]; then
    echo "nameko service in debug mode. please connect to port 5678 to start service"
    GEVENT_SUPPORT=True python -m debugpy --listen 5678 --wait-for-client run_nameko.py run --config config.yaml $@
else
    python run_nameko.py run --config config.yaml $@
fi
