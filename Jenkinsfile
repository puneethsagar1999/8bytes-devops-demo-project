pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        AWS_REGION   = 'us-east-1'
        AWS_ACCOUNT  = '484799953929'
        ECR_REGISTRY = "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPO     = "${ECR_REGISTRY}/devops-staging-staging-app"
        CLUSTER_NAME = 'devops-staging-staging-eks'
        NOTIFY_EMAIL = 'wonderlustp05@gmail.com'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    env.IMAGE_TAG = sh(returnStdout: true, script: 'git rev-parse --short=7 HEAD').trim()
                }
                echo "Image tag: ${env.IMAGE_TAG}"
            }
        }

        stage('Unit tests') {
            steps {
                sh '''
                  docker run --rm -v "$PWD/app":/src:ro python:3.12-slim \
                    sh -c "cp -r /src /app && cd /app && pip install -q -r requirements.txt pytest && pytest -v test_app.py"
                '''
            }
        }

        stage('Integration tests') {
            steps {
                sh '''
                  set -e
                  NET="it-net-$$"
                  PG="itpg-$$"
                  cleanup() { docker rm -f "$PG" >/dev/null 2>&1 || true; docker network rm "$NET" >/dev/null 2>&1 || true; }
                  trap cleanup EXIT
                  docker network create "$NET"
                  docker run -d --name "$PG" --network "$NET" -e POSTGRES_PASSWORD=pass -e POSTGRES_DB=appdb postgres:16
                  for i in $(seq 1 30); do docker exec "$PG" pg_isready -U postgres -d appdb && break; sleep 2; done
                  sleep 5
                  docker run --rm --network "$NET" -v "$PWD/app":/src:ro \
                    -e DB_HOST="$PG" -e DB_USER=postgres -e DB_PASSWORD=pass \
                    python:3.12-slim sh -c "cp -r /src /app && cd /app && pip install -q -r requirements.txt pytest && pytest -v test_integration.py"
                '''
            }
        }

        stage('Dependency scan') {
            steps {
                sh '''
                  docker run --rm -v "$PWD/app":/src:ro python:3.12-slim \
                    sh -c "pip install -q pip-audit && pip-audit -r /src/requirements.txt"
                '''
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build -t $ECR_REPO:$IMAGE_TAG app'
            }
        }

        stage('Container scan') {
            steps {
                sh '''
                  docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v trivy-cache:/root/.cache/ \
                    aquasec/trivy:latest image \
                    --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --no-progress \
                    $ECR_REPO:$IMAGE_TAG
                '''
            }
        }

        stage('Push to ECR') {
            when { branch 'main' }
            steps {
                sh '''
                  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
                  docker push $ECR_REPO:$IMAGE_TAG
                '''
            }
        }

        stage('Deploy to staging') {
            when { branch 'main' }
            steps {
                sh '''
                  aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
                  helm upgrade --install demo-app deploy/chart \
                    --namespace staging \
                    -f deploy/values-staging.yaml \
                    --set image.repository=$ECR_REPO \
                    --set image.tag=$IMAGE_TAG \
                    --wait --timeout 5m
                  kubectl rollout status deployment/demo-app -n staging --timeout=120s
                '''
            }
        }

        stage('Approve production') {
            when { branch 'main' }
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: "Deploy ${env.IMAGE_TAG} to production?", ok: 'Deploy'
                }
            }
        }

        stage('Deploy to production') {
            when { branch 'main' }
            steps {
                sh '''
                  helm upgrade --install demo-app deploy/chart \
                    --namespace production \
                    -f deploy/values-production.yaml \
                    --set image.repository=$ECR_REPO \
                    --set image.tag=$IMAGE_TAG \
                    --wait --timeout 5m
                  kubectl rollout status deployment/demo-app -n production --timeout=120s
                '''
            }
        }
    }

    post {
        failure {
            emailext to: env.NOTIFY_EMAIL,
                     subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                     body: "The build failed.\n\nDetails: ${env.BUILD_URL}"
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}