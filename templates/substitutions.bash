sed -i "s^PLACEHOLDER_STACKNAME^${STACKNAME}^g" *.template
sed -i "s^PLACEHOLDER_PREFIX^${PREFIX}^g" *.template
sed -i "s^PLACEHOLDER_HOME^${HOME}^g" *.template
sed -i "s^PLACEHOLDER_PORT^${PORT}^g" *.template
sed -i "s^PLACEHOLDER_DOMAIN1^${DOMAIN1}^g" *.template
sed -i "s^PLACEHOLDER_APPDIR1^${APPDIR1}^g" *.template
