// =============================================================================
// Dynamic CI/CD Pipeline - Declarative Jenkinsfile
// =============================================================================
// This Jenkinsfile defines an enterprise-grade CI/CD pipeline that:
//   1. Builds a Spring Boot application using dynamic Maven/JDK agents
//   2. Runs unit & integration tests with JaCoCo coverage
//   3. Performs SonarQube static code analysis (localhost:9000)
//   4. Scans Docker images with Trivy for vulnerabilities
//   5. Pushes versioned images to Nexus registry
//   6. Auto-deploys to staging environment
//   7. Blue-green deploys to production with manual approval
//
// IMPORTANT NOTES:
//   - Jenkins is running on localhost:8086
//   - SonarQube is running on localhost:9000
//   - Dynamic agents are provisioned as K8s pods
// =============================================================================

pipeline {
    // Use the maven-jdk pod template as the default agent
    agent {
        kubernetes {
            label 'maven-jdk'
            defaultContainer 'maven'
        }
    }

    // =========================================================================
    // Environment Variables
    // =========================================================================
    environment {
        // Application configuration
        APP_NAME          = 'pipeline-demo-app'
        APP_VERSION       = '1.0.0'

        // Docker / Registry configuration
        DOCKER_REGISTRY   = 'localhost:30082'
        IMAGE_NAME        = "${DOCKER_REGISTRY}/${APP_NAME}"
        IMAGE_TAG         = "${APP_VERSION}-${BUILD_NUMBER}"
        IMAGE_FULL        = "${IMAGE_NAME}:${IMAGE_TAG}"
        IMAGE_LATEST      = "${IMAGE_NAME}:latest"

        // SonarQube configuration (user's localhost:9000)
        SONAR_HOST_URL    = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'pipeline-demo-app'

        // Kubernetes namespaces
        STAGING_NS        = 'staging'
        PRODUCTION_NS     = 'production'

        // Credentials (stored in Jenkins Credentials Store)
        NEXUS_CREDENTIALS = credentials('nexus-credentials')
        SONAR_TOKEN       = credentials('sonarqube-token')
        GIT_CREDENTIALS   = credentials('git-credentials')
    }

    // =========================================================================
    // Pipeline Options
    // =========================================================================
    options {
        // Add timestamps to console output
        timestamps()

        // Discard old builds (keep last 10)
        buildDiscarder(logRotator(numToKeepStr: '10'))

        // Timeout for the entire pipeline (60 minutes)
        timeout(time: 60, unit: 'MINUTES')

        // Do not allow concurrent builds
        disableConcurrentBuilds()

        // Skip default SCM checkout (we do it manually)
        skipDefaultCheckout(true)
    }

    // =========================================================================
    // Trigger on push to main branch via webhook
    // =========================================================================
    triggers {
        githubPush()
    }

    // =========================================================================
    // Pipeline Stages
    // =========================================================================
    stages {

        // =====================================================================
        // Stage 1: Checkout Source Code
        // =====================================================================
        stage('Checkout') {
            steps {
                echo '🔄 Checking out source code from Git repository...'
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    echo "📌 Commit: ${env.GIT_COMMIT_SHORT} - ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        // =====================================================================
        // Stage 2: Build Application
        // =====================================================================
        stage('Build') {
            steps {
                echo '🏗️ Building application with Maven...'
                container('maven') {
                    dir('sample-app') {
                        sh '''
                            mvn clean compile -B -DskipTests \
                                -Dmaven.repo.local=/home/jenkins/agent/.m2/repository
                        '''
                    }
                }
            }
        }

        // =====================================================================
        // Stage 3: Parallel - Unit Tests & SonarQube Analysis
        // =====================================================================
        stage('Test & Analysis') {
            parallel {
                // ---------------------------------------------------------
                // Stage 3a: Unit & Integration Tests
                // ---------------------------------------------------------
                stage('Unit & Integration Tests') {
                    steps {
                        echo '🧪 Running unit and integration tests...'
                        container('maven') {
                            dir('sample-app') {
                                sh '''
                                    mvn test verify -B \
                                        -Dmaven.repo.local=/home/jenkins/agent/.m2/repository
                                '''
                            }
                        }
                    }
                    post {
                        always {
                            // Publish test results
                            junit allowEmptyResults: true,
                                  testResults: 'sample-app/target/surefire-reports/*.xml'

                            // Publish JaCoCo coverage report
                            jacoco(
                                execPattern: 'sample-app/target/jacoco.exec',
                                classPattern: 'sample-app/target/classes',
                                sourcePattern: 'sample-app/src/main/java',
                                exclusionPattern: 'sample-app/src/test*'
                            )
                        }
                    }
                }

                // ---------------------------------------------------------
                // Stage 3b: SonarQube Code Quality Analysis
                // ---------------------------------------------------------
                stage('SonarQube Analysis') {
                    steps {
                        echo '🔍 Running SonarQube static code analysis...'
                        container('maven') {
                            dir('sample-app') {
                                withSonarQubeEnv('SonarQube') {
                                    sh '''
                                        mvn sonar:sonar -B \
                                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                            -Dsonar.projectName="Pipeline Demo Application" \
                                            -Dsonar.host.url=${SONAR_HOST_URL} \
                                            -Dsonar.login=${SONAR_TOKEN} \
                                            -Dsonar.java.coveragePlugin=jacoco \
                                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                                            -Dmaven.repo.local=/home/jenkins/agent/.m2/repository
                                    '''
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // Stage 4: Quality Gate Check
        // Pipeline fails if SonarQube quality gate is not met
        // =====================================================================
        stage('Quality Gate') {
            steps {
                echo '🚦 Waiting for SonarQube Quality Gate result...'
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
                echo '✅ Quality Gate PASSED!'
            }
        }

        // =====================================================================
        // Stage 5: Package Application
        // =====================================================================
        stage('Package') {
            steps {
                echo '📦 Packaging application JAR...'
                container('maven') {
                    dir('sample-app') {
                        sh '''
                            mvn package -B -DskipTests \
                                -Dmaven.repo.local=/home/jenkins/agent/.m2/repository
                        '''
                    }
                }
                // Archive the JAR artifact
                archiveArtifacts artifacts: 'sample-app/target/*.jar',
                                 fingerprint: true
            }
        }

        // =====================================================================
        // Stage 6: Docker Image Build & Push
        // Uses the docker-agent pod template
        // =====================================================================
        stage('Image Build & Push') {
            agent {
                kubernetes {
                    label 'docker-agent'
                    defaultContainer 'docker'
                }
            }
            steps {
                echo "🐳 Building Docker image: ${IMAGE_FULL}"
                checkout scm
                container('docker') {
                    dir('sample-app') {
                        // Start Docker daemon in background
                        sh 'dockerd &'
                        sh 'sleep 5'

                        // Build the Docker image with versioned tags
                        sh """
                            docker build \
                                --build-arg APP_VERSION=${APP_VERSION} \
                                --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                                -t ${IMAGE_FULL} \
                                -t ${IMAGE_LATEST} \
                                -t ${IMAGE_NAME}:${GIT_COMMIT_SHORT} \
                                .
                        """

                        // Push to Nexus Docker registry
                        sh """
                            echo '${NEXUS_CREDENTIALS_PSW}' | docker login ${DOCKER_REGISTRY} \
                                -u '${NEXUS_CREDENTIALS_USR}' --password-stdin

                            docker push ${IMAGE_FULL}
                            docker push ${IMAGE_LATEST}
                            docker push ${IMAGE_NAME}:${GIT_COMMIT_SHORT}
                        """

                        echo "✅ Image pushed: ${IMAGE_FULL}"
                    }
                }
            }
        }

        // =====================================================================
        // Stage 7: Security Scan with Trivy
        // Scans the built Docker image for CVEs
        // Fails the pipeline on CRITICAL vulnerabilities
        // =====================================================================
        stage('Security Scan') {
            agent {
                kubernetes {
                    label 'docker-agent'
                    defaultContainer 'trivy'
                }
            }
            steps {
                echo "🔒 Scanning image for vulnerabilities: ${IMAGE_FULL}"
                container('trivy') {
                    // Generate table report for console output
                    sh """
                        trivy image \
                            --severity CRITICAL,HIGH \
                            --no-progress \
                            --format table \
                            ${IMAGE_FULL} || true
                    """

                    // Generate JSON report for archiving
                    sh """
                        trivy image \
                            --severity CRITICAL,HIGH \
                            --no-progress \
                            --format json \
                            --output trivy-report.json \
                            ${IMAGE_FULL} || true
                    """

                    // Fail on CRITICAL vulnerabilities only
                    sh """
                        trivy image \
                            --severity CRITICAL \
                            --exit-code 1 \
                            --no-progress \
                            --format table \
                            ${IMAGE_FULL}
                    """
                }
                // Archive the vulnerability report
                archiveArtifacts artifacts: 'trivy-report.json',
                                 allowEmptyArchive: true
                echo '✅ Security scan PASSED - No CRITICAL vulnerabilities found!'
            }
        }

        // =====================================================================
        // Stage 8: Deploy to Staging (Automatic)
        // Deploys the new version to the staging environment automatically
        // =====================================================================
        stage('Deploy to Staging') {
            agent {
                kubernetes {
                    label 'kubectl-agent'
                    defaultContainer 'kubectl'
                }
            }
            steps {
                echo "🚀 Deploying ${IMAGE_FULL} to STAGING environment..."
                lock(resource: 'staging-deployment') {
                    container('kubectl') {
                        // Update the staging deployment with the new image
                        sh """
                            kubectl set image deployment/pipeline-demo-app \
                                pipeline-demo-app=${IMAGE_FULL} \
                                -n ${STAGING_NS}
                        """

                        // Wait for rollout to complete
                        sh """
                            kubectl rollout status deployment/pipeline-demo-app \
                                -n ${STAGING_NS} \
                                --timeout=300s
                        """

                        // Verify the deployment
                        sh """
                            echo '--- Staging Pods ---'
                            kubectl get pods -n ${STAGING_NS} -l app=pipeline-demo-app
                            echo ''
                            echo '--- Staging Service ---'
                            kubectl get svc -n ${STAGING_NS} pipeline-demo-app-service
                        """

                        // Run smoke test against staging
                        script {
                            def stagingUrl = sh(
                                script: "kubectl get svc pipeline-demo-app-service -n ${STAGING_NS} -o jsonpath='{.spec.clusterIP}'",
                                returnStdout: true
                            ).trim()
                            sh """
                                echo "Running smoke test against staging..."
                                for i in 1 2 3 4 5; do
                                    if wget -q -O - http://${stagingUrl}:8080/api/health 2>/dev/null | grep -q 'UP'; then
                                        echo "✅ Smoke test passed on attempt \$i"
                                        exit 0
                                    fi
                                    echo "Attempt \$i failed, retrying in 10s..."
                                    sleep 10
                                done
                                echo "❌ Smoke test failed after 5 attempts"
                                exit 1
                            """
                        }
                    }
                }
                echo '✅ Staging deployment successful!'
            }
        }

        // =====================================================================
        // Stage 9: Manual Approval for Production
        // Requires human approval before deploying to production
        // =====================================================================
        stage('Production Approval') {
            steps {
                echo '⏸️ Awaiting manual approval for PRODUCTION deployment...'
                script {
                    def approvalMessage = """
                        🚀 PRODUCTION DEPLOYMENT APPROVAL REQUIRED
                        
                        Application: ${APP_NAME}
                        Version:     ${IMAGE_TAG}
                        Git Commit:  ${GIT_COMMIT_SHORT}
                        
                        Staging deployment has been validated.
                        Please review and approve to proceed with blue-green production deployment.
                    """.stripIndent()

                    timeout(time: 30, unit: 'MINUTES') {
                        input(
                            message: approvalMessage,
                            ok: '🚀 Deploy to Production',
                            submitter: 'admin',
                            submitterParameter: 'approver'
                        )
                    }
                }
                echo '✅ Production deployment approved!'
            }
        }

        // =====================================================================
        // Stage 10: Blue-Green Production Deployment
        // Implements zero-downtime deployment with instant rollback capability
        // =====================================================================
        stage('Blue-Green Deploy') {
            agent {
                kubernetes {
                    label 'kubectl-agent'
                    defaultContainer 'kubectl'
                }
            }
            steps {
                echo "🔵🟢 Starting Blue-Green deployment to PRODUCTION..."
                lock(resource: 'production-deployment') {
                    container('kubectl') {
                        script {
                            // Step 1: Determine the current active color
                            def currentColor = sh(
                                script: """
                                    kubectl get svc pipeline-demo-app-service \
                                        -n ${PRODUCTION_NS} \
                                        -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo 'blue'
                                """,
                                returnStdout: true
                            ).trim()

                            // Determine the idle (target) color
                            def targetColor = (currentColor == 'blue') ? 'green' : 'blue'
                            def targetDeployment = "pipeline-demo-app-${targetColor}"

                            echo "📊 Current active: ${currentColor} | Deploying to: ${targetColor}"

                            // Step 2: Deploy the new version to the idle color
                            sh """
                                kubectl set image deployment/${targetDeployment} \
                                    pipeline-demo-app=${IMAGE_FULL} \
                                    -n ${PRODUCTION_NS}
                            """

                            // Step 3: Update environment variables for the target deployment
                            sh """
                                kubectl set env deployment/${targetDeployment} \
                                    APP_VERSION=${IMAGE_TAG} \
                                    DEPLOYMENT_COLOR=${targetColor} \
                                    BUILD_NUMBER=${BUILD_NUMBER} \
                                    -n ${PRODUCTION_NS}
                            """

                            // Step 4: Wait for the idle deployment to be ready
                            sh """
                                kubectl rollout status deployment/${targetDeployment} \
                                    -n ${PRODUCTION_NS} \
                                    --timeout=300s
                            """

                            // Step 5: Run smoke tests against the idle deployment
                            def targetPodIP = sh(
                                script: """
                                    kubectl get pods -n ${PRODUCTION_NS} \
                                        -l app=pipeline-demo-app,version=${targetColor} \
                                        -o jsonpath='{.items[0].status.podIP}'
                                """,
                                returnStdout: true
                            ).trim()

                            sh """
                                echo "Running smoke tests against ${targetColor} deployment..."
                                for i in 1 2 3 4 5; do
                                    if wget -q -O - http://${targetPodIP}:8080/api/health 2>/dev/null | grep -q 'UP'; then
                                        echo "✅ ${targetColor} smoke test passed on attempt \$i"
                                        break
                                    fi
                                    if [ \$i -eq 5 ]; then
                                        echo "❌ Smoke test failed for ${targetColor} deployment"
                                        exit 1
                                    fi
                                    echo "Attempt \$i failed, retrying in 10s..."
                                    sleep 10
                                done
                            """

                            // Step 6: Switch traffic to the new color
                            echo "🔄 Switching production traffic: ${currentColor} → ${targetColor}"
                            sh """
                                kubectl patch service pipeline-demo-app-service \
                                    -n ${PRODUCTION_NS} \
                                    -p '{"spec":{"selector":{"version":"${targetColor}"}}}'
                            """

                            // Step 7: Update service annotation
                            sh """
                                kubectl annotate service pipeline-demo-app-service \
                                    -n ${PRODUCTION_NS} \
                                    deployment.kubernetes.io/active-color=${targetColor} \
                                    --overwrite
                            """

                            // Step 8: Verify the switch
                            sh """
                                echo ''
                                echo '========================================='
                                echo '  🎉 BLUE-GREEN DEPLOYMENT COMPLETE'
                                echo '========================================='
                                echo "  Active Color:  ${targetColor}"
                                echo "  Image:         ${IMAGE_FULL}"
                                echo "  Build:         #${BUILD_NUMBER}"
                                echo "  Previous:      ${currentColor} (kept for rollback)"
                                echo '========================================='
                                echo ''
                                echo '--- Production Pods ---'
                                kubectl get pods -n ${PRODUCTION_NS} -l app=pipeline-demo-app --show-labels
                                echo ''
                                echo '--- Production Service ---'
                                kubectl get svc pipeline-demo-app-service -n ${PRODUCTION_NS}
                            """

                            // Save rollback information
                            env.PREVIOUS_COLOR = currentColor
                            env.ACTIVE_COLOR = targetColor
                        }
                    }
                }
                echo '✅ Production blue-green deployment successful!'
            }
        }
    }

    // =========================================================================
    // Post-Pipeline Actions
    // =========================================================================
    post {
        success {
            echo '''
                ═══════════════════════════════════════════════
                  ✅ PIPELINE COMPLETED SUCCESSFULLY
                ═══════════════════════════════════════════════
                All stages passed:
                  ✓ Build & Compilation
                  ✓ Unit & Integration Tests
                  ✓ SonarQube Quality Gate
                  ✓ Security Vulnerability Scan
                  ✓ Docker Image Build & Push
                  ✓ Staging Deployment
                  ✓ Production Blue-Green Deployment
                ═══════════════════════════════════════════════
            '''
        }

        failure {
            echo '''
                ═══════════════════════════════════════════════
                  ❌ PIPELINE FAILED
                ═══════════════════════════════════════════════
                Please check the stage logs above for details.
                ═══════════════════════════════════════════════
            '''
        }

        unstable {
            echo '⚠️ Pipeline completed with warnings. Please review test results.'
        }

        always {
            // Clean up workspace
            cleanWs(
                cleanWhenNotBuilt: false,
                deleteDirs: true,
                disableDeferredWipeout: true,
                notFailBuild: true
            )
        }
    }
}
