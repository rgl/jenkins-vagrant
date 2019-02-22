
JCLI="java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080"

# wait for the cli endpoint to be available.
function jcliwait {
    bash -c 'while ! wget -q --spider http://localhost:8080/cli; do sleep 1; done;'
}

function jcli {
    $JCLI -http -auth @$HOME/.jenkins-cli "$@"
}

function jgroovy {
    jcli groovy "$@"
}
