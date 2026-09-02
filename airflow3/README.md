# Airflow 3

Run:

```bash
curl -sfL https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/airflow3/install-airflow3.docker.sh | sh -
```

Change installation folder:

```bash
curl -sfL https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/airflow3/install-airflow3.docker.sh | AIRFLOW_FOLDER=my-airflow sh -
```

To load examples, set `AIRFLOW_LOAD_EXAMPLES=true`.

See also [Official Airflow Docs](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html)

## Clean-up

```bash
docker compose down --volumes --remove-orphans
```
