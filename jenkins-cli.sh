
JCLI="java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080"

function jcli {
    $JCLI -http -auth @$HOME/.jenkins-cli "$@"
}

function jgroovy {
    jcli groovy "$@"
}
