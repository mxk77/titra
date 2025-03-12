#!/bin/bash
if [ -n "${MONGO_URL:-}" ]; then
    echo 'Connecting to MongoDB...'
    # Change directory to where the Meteor MongoDB client is located within the bundle
    cd bundle/programs/server/npm/node_modules/meteor/npm-mongo/node_modules
    node <<-'EOJS'
	const mongoClient = require('mongodb').MongoClient;
	setInterval(async function() {
		let client;
		try {
			client = await mongoClient.connect(process.env.MONGO_URL, { useUnifiedTopology: true });
		} catch (err) {
			console.error(err.message);
		}
		if (client && client.topology && client.topology.isConnected()) {
			console.log('Successfully connected to MongoDB');
			client.close();
			process.exit(0);
		}
	}, 1000);
	EOJS
fi
# Return to /app directory and start the application
cd /app
echo 'Starting titra...'
exec "$@"