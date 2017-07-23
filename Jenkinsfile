#!groovy

@Library("mySharedLibs") _

node {
  timestamps {
    String buildNumber = "0.0.1-b${env.BUILD_NUMBER}"
    String caddyScm = "https://github.com/mholt/caddy.git"
    String deployscm = "https://github.com/bimlendu/caddy-hugo.git"
    String prj = "github.com/mholt/caddy"
    String goSrc = "src/" + prj

    String go_root = tool name: 'GO_1.8.3', type: 'go'
    String sonarqubeScannerHome = tool name: 'SonarScanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
    String deployBucket = 'alpha-caddy-deploy'
    String deployAppName = 'alpha-code-deploy-app'
    String deployGroupName = 'alpha-deploy-group'

    String statusPage_pageID = 'b1yh4zryjdsf'
    String statusPage_APIEndpoint = 'https://api.statuspage.io/v1/'
    String statuspage_ComponentID = 'nc10rhbss2yj'

    withEnv(["GOROOT=${go_root}", "GOPATH=${WORKSPACE}", "GOBIN=${WORKSPACE}/bin", "PATH+GO=${go_root}/bin:${WORKSPACE}/bin"]){

      stage('Checkout'){
        checkout changelog: true, poll: false, scm: [$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: goSrc]], submoduleCfg: [], userRemoteConfigs: [[url: caddyScm]]]
      }

      stage('AddHugo'){
        _sh "sed -i 's~\"github.com/mholt/caddy/caddytls\"~\"github.com/mholt/caddy/caddytls\"\\n_ \"github.com/hacdias/filemanager/caddy/filemanager\"\\n_ \"github.com/hacdias/filemanager/caddy/hugo\"~g' " + goSrc + "/caddy/caddymain/run.go"
      }

      stage('getDependencies'){
        _sh 'go get -d -t -v ' + prj + '/...'
        _sh 'go get -u -v gopkg.in/alecthomas/gometalinter.v1 github.com/axw/gocov/... github.com/AlekSi/gocov-xml github.com/jstemmer/go-junit-report github.com/360EntSecGroup-Skylar/goreporter'
      }

      stage('ParallelTests'){
        parallel(
          Coverage: {
            _sh '''
for pkg in $(go list github.com/mholt/caddy/... | grep -v /vendor/ );
do
  echo "testing... $pkg"
  go test -coverprofile=src/$pkg/cover.out $pkg
  gocov convert src/$pkg/cover.out | gocov-xml > src/$pkg/coverage.xml
done
'''
          },
          Lint: {
            _sh 'gometalinter.v1 --install'
            _sh 'gometalinter.v1 --disable-all --enable=errcheck --enable=vet --checkstyle --deadline 5m ' + goSrc + ' > report.xml || true'
          },
          UnitTests: {
            _sh 'go test -v 2>&1 | go-junit-report > test.xml'
            junit allowEmptyResults: true, testResults: 'test.xml'
          }
        )
      }

      stage('Sonar'){
        withSonarQubeEnv('Sonar') { 
          _sh sonarqubeScannerHome + '/bin/sonar-scanner ' + 
          '-Dsonar.projectKey=caddy-hugo ' +
          '-Dsonar.projectName=caddy-hugo ' +
          '-Dsonar.projectVersion=' + buildNumber + ' ' +
          '-Dsonar.golint.reportPath=report.xml ' +
          '-Dsonar.coverage.reportPath=coverage.xml ' +
          '-Dsonar.coverage.dtdVerification=true ' +
          '-Dsonar.test.reportPath=test.xml ' +
          '-Dsonar.sources=./' + goSrc + ' ' + 
          '-Dsonar.exclusions=vendor/**,.git/**,**/*test.go,**/*.xml ' + 
          '-Dsonar.showProfiling=true ' +
          '-Dsonar.test.exclusions=**/*test.go'
        }
      }

      stage('Build') {
        _sh 'mkdir -p release'
        _sh 'go build -o release/caddy github.com/mholt/caddy/caddy'
        _sh 'chmod 755 release/caddy'
        _sh './release/caddy -plugins | grep hugo'
        archiveArtifacts allowEmptyArchive: true, artifacts: 'release/caddy', fingerprint: true, onlyIfSuccessful: true
      }

      stage('Package') {
        checkout changelog: true, poll: false, scm: [$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'deploy']], submoduleCfg: [], userRemoteConfigs: [[url: deployscm]]]

        dir('deploy/codedeploy'){
          writeFile file: 'version', text: 'Caddy With Hugo. \n\nVersion: ' + buildNumber + '\n\nBuild Time: ' + new Date()
          _sh 'mv ../../release/caddy .'
          _sh 'rm -rf *.zip && zip -r caddy-' + buildNumber + '.zip .' 
          s3Upload(file:'caddy-' + buildNumber + '.zip', bucket:deployBucket, path:'caddy-' + buildNumber + '.zip' )
        }
      }

      stage('Deploy') {
        withCredentials([
          usernamePassword(credentialsId: 'msg_provider', passwordVariable: 'auth_key', usernameVariable: 'auth_id'),
          string(credentialsId: 'statusPageAPIKey', variable: 'statuspage_api_key'),
          string(credentialsId: 'srcPhone', variable: 'srcPhone'),
          string(credentialsId: 'destPhone', variable: 'destPhone')]
        ) {
            String incName = 'Start deployment - ' + env.BUILD_URL
            String startDeployMsg = 'Deploying ' + deployAppName + ' : ' + buildNumber

            String _inc = createStatusPageInc(statusPage_APIEndpoint, statuspage_api_key, statuspage_ComponentID, statusPage_pageID, startDeployMsg, incName)
          
            sendSMS('msg_provider', auth_id, srcPhone, destPhone, incName)
      
            codeDeploy(deployAppName, deployGroupName, deployBucket, 'caddy-' + buildNumber + '.zip', 15)
            
            String postDeployMsg = 'Deployment Completed. ' + deployAppName + ' : ' + buildNumber
            
            resolveStatusPageInc(statusPage_APIEndpoint, statuspage_api_key, statuspage_ComponentID, statusPage_pageID, _inc, postDeployMsg)

            sendSMS('msg_provider', auth_id, srcPhone, destPhone, postDeployMsg)
          }
      }
    }
    cleanWs()
  }
}