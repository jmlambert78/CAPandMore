 awk '(/vvvvv/||/PWD/||/\^/){next}/^2019/{print}' $AKSDEPLOYID/history_actions.log
