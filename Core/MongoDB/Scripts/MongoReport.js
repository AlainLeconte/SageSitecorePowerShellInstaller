printjson("List Databases & Users");
dbs = db.getMongo().getDBNames()
dbs.forEach(function(dbName, index) {
		printjson("Database: " + dbName);
		cdb = db.getSiblingDB(dbName);
		users =  cdb.getUsers();
				users.forEach(function(item, index) {
						printjson(item);
		});
});

