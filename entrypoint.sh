#!/bin/bash

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}


DBHOST=`echo $VCAP_SERVICES | jq -r '.postgresql[0].credentials.host'`
DBPORT=`echo $VCAP_SERVICES | jq -r '.postgresql[0].credentials.port'`
DBUSER=`echo $VCAP_SERVICES | jq -r '.postgresql[0].credentials.username'`
DBPASS=`echo $VCAP_SERVICES | jq -r '.postgresql[0].credentials.password'`
DBNAME=`echo $VCAP_SERVICES | jq -r '.postgresql[0].credentials.database'`

check_config "db_host" "$DBHOST"
check_config "db_port" "$DBPORT"
check_config "db_user" "$DBUSER"
check_config "db_password" "$DBPASS"
check_config "database" "$DBNAME"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            TABLE=res_company
            SQL_EXISTS=$(printf '\dt "%s"' "$TABLE")
            if [[ $(PGPASSWORD="$DBPASS" psql -h "$DBHOST" -U $DBUSER -d $DBNAME -c "$SQL_EXISTS") ]]
            then
              echo "ODOO Table exists"
              exec odoo "$@" "${DB_ARGS[@]}" --no-database-list
            else
              wait-for-psql.py ${DB_ARGS[@]} --timeout=30
              exec odoo "$@" "${DB_ARGS[@]}" -i base --without-demo=base --no-database-list 
            fi
        fi
        ;;
    -*)
        wait-for-psql.py ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
