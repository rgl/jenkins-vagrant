
JCLI="java -jar /var/cache/jenkins/war/WEB-INF/lib/cli-*.jar -s https://$domain"

# wait for the cli endpoint to be available.
function jcliwait {
    bash -c "while ! wget -q --spider https://$domain/health/; do sleep 1; done;"
    bash -c "while ! wget -q --spider https://$domain/cli; do sleep 1; done;"
}

function jcli {
    $JCLI -auth @$HOME/.jenkins-cli "$@"
}

function jgroovy {
    jcli groovy "$@"
}
