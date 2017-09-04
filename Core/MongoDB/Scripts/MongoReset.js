printjson("-- Reset MongoDb instance --");
printjson('Delete Users & Database');
var db = db.getSiblingDB('admin');
var dbs = db.getMongo().getDBNames()
dbs.forEach(function(dbName, index) {
		printjson("Database: " + dbName);
		if (dbName != "local") {
			cdb = db.getSiblingDB(dbName);
			cdb.dropAllUsers({w: "majority", wtimeout: 5000});
			printjson(">> All users dropped.");
			if (dbName != "admin") {
				cdb.runCommand({dropDatabase: 1})
				printjson(">> " + dbName + " database dropped.");
			}
		}
});

printjson("");
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