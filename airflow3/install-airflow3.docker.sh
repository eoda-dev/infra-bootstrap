#!/bin/sh
airflow_folder=${AIRFLOW_FOLDER:-airflow3-docker}
echo $airflow_folder
airflow_load_examples=${AIRFLOW_LOAD_EXAMPLES:-false}
echo "airflow_load_examples: $airflow_load_examples"

mkdir -p $airflow_folder && cd $airflow_folder
curl -LfO 'https://airflow.apache.org/docs/apache-airflow/3.3.1/docker-compose.yaml'
mkdir -p ./dags ./logs ./plugins ./config
echo "AIRFLOW_UID=$(id -u)" > .env
sed -i "s/AIRFLOW__CORE__LOAD_EXAMPLES: '.*'/AIRFLOW__CORE__LOAD_EXAMPLES: '$airflow_load_examples'/" docker-compose.yaml
# docker compose run airflow-cli airflow config list
docker compose up airflow-init
# docker compose up -d
