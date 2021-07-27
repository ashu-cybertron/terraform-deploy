#!/bin/bash

set -x

function wait_for_jenkins()
{
  while (( 1 )); do
      echo "waiting for Jenkins to launch on port [8080] ..."
      
      nc -zv 127.0.0.1 8080
      if (( $? == 0 )); then
          break
      fi

      sleep 10
  done

  echo "Jenkins launched"
}

function updating_jenkins_master_password ()
{
  jenkins_admin_password="admin123"

  cat > /tmp/jenkinsHash.py <<EOF
import bcrypt
import sys
if not sys.argv[1]:
  sys.exit(10)
plaintext_pwd=sys.argv[1]
encrypted_pwd=bcrypt.hashpw(sys.argv[1], bcrypt.gensalt(rounds=10, prefix=b"2a"))
isCorrect=bcrypt.checkpw(plaintext_pwd, encrypted_pwd)
if not isCorrect:
  sys.exit(20);
print "{}".format(encrypted_pwd)
EOF

  chmod +x /tmp/jenkinsHash.py
  systemctl restart jenkins
  
  # Wait till /var/lib/jenkins/users/admin* folder gets created

  # cd /var/lib/jenkins/users/admin*

  while (( 1 )); do       
    echo "Waiting for Jenkins to generate admin user's config file ..."        
    
    if [ -f /var/lib/jenkins/users/admin_*/config.xml ]; then           
        break;       
    fi;        
    
    sleep 10;   
  done

  echo "Admin config file created"
  cd /var/lib/jenkins/users/admin*
  pwd

  admin_password=$(python /tmp/jenkinsHash.py ${jenkins_admin_password} 2>&1)
  
  # Please do not remove alter quote as it keeps the hash syntax intact or else while substitution, $<character> will be replaced by null
  xmlstarlet -q ed --inplace -u "/user/properties/hudson.security.HudsonPrivateSecurityRealm_-Details/passwordHash" -v '#jbcrypt:'"$admin_password" config.xml

  # Restart
  systemctl restart jenkins
  sleep 10
}

function install_packages ()
{

  sudo wget -O /etc/yum.repos.d/jenkins.repo     https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
  sudo yum upgrade -y
  sudo yum install jenkins java-1.8.0-openjdk-devel -y
  # firewall for  local machine firewallsetting 
  #firewall-cmd --permanent --new-service=jenkins
  #firewall-cmd --permanent --service=jenkins --set-short="Jenkins Service Ports"
  #firewall-cmd --permanent --service=jenkins --set-description="Jenkins Service firewalld port exceptions"
  #firewall-cmd --permanent --service=jenkins --add-port=8080/tcp
  #firewall-cmd --permanent --add-service=jenkins
  #firewall-cmd --zone=public --add-service=http --permanent
  #firewall-cmd --reload
  systemctl start jenkins
  systemctl enable jenkins
  systemctl restart jenkins
  sleep 20
  sudo yum install docker -y
  systemctl start docker 
  systemctl enable docker 
  sleep 10
  systemctl restart jenkins
}

function configure_jenkins_server ()
{
  wait_for_jenkins

  sleep 10

  # Jenkins cli
  echo "installing the Jenkins cli ..."
  # cp /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar /var/lib/jenkins/jenkins-cli.jar

  while ((1)); do
     wget -O /var/lib/jenkins/jenkins-cli.jar http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar

     if [[ $? -eq 0 ]]; then
         break
     fi

     sleep 10
      
  done

  

  # Getting initial password
  # PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
  PASSWORD="admin123"
  sleep 10

  jenkins_dir="/var/lib/jenkins"
  plugins_dir="$jenkins_dir/plugins"

  cd $jenkins_dir

  # Open JNLP port
  xmlstarlet -q ed --inplace -u "/hudson/slaveAgentPort" -v 33453 config.xml

  cd $plugins_dir || { echo "unable to chdir to [$plugins_dir]"; exit 1; }

  # List of plugins that are needed to be installed 
  plugin_list="git-client git github-api github-oauth github MSBuild ssh-slaves workflow-aggregator ws-cleanup"

  # remove existing plugins, if any ...
  rm -rfv $plugin_list

  for plugin in $plugin_list; do
      echo "installing plugin [$plugin] ..."
      java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080/ -auth admin:$PASSWORD install-plugin $plugin
  done

  # Restart jenkins after installing plugins
  java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080 -auth admin:$PASSWORD safe-restart
}

function create_user () 
{
  PASSWORD="admin123"

  while ((1)); do
     echo 'jenkins.model.Jenkins.instance.securityRealm.createAccount("Teqforce", "Teqforce!1")' | java -jar /var/lib/jenkins/jenkins-cli.jar -s "http://127.0.0.1:8080" -auth admin:$PASSWORD -noKeyAuth groovy = –

     if [[ $? -eq 0 ]]; then
         break
     fi

     sleep 10      
  done
}

### script starts here ###

install_packages

wait_for_jenkins

updating_jenkins_master_password

wait_for_jenkins

configure_jenkins_server

create_user

echo "Done"
exit 0