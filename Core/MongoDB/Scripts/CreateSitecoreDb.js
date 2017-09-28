var db = db.getSiblingDB('admin');
db.dropAllUsers({w: "majority", wtimeout: 5000});

printjson("changed the authSchema value to 3 (which stands for MONGODB-CR)");
var schema = db.system.version.findOne({"_id" : "authSchema"}) 
schema.currentVersion = 3 
db.system.version.save(schema)  

db.createUser(
  {
    user: "MongoAdminUser",
    pwd: "password",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" } , { role: "root", db: "admin" } ]
  }
);

var sitecoreDbs = ['<prefix>_analytics', '<prefix>_tracking_live', '<prefix>_tracking_history', '<prefix>_tracking_contact'];
sitecoreDbs.forEach(function(dbName, index) {
	printjson("");
	printjson("-- " + dbName + " --");
	db = db.getSiblingDB(dbName);
	db.dropAllUsers({w: "majority", wtimeout: 5000});
	db.createUser(
		{
		  user: "sageunitymongouser",
		  pwd: "URuWCpF8nSkwLkh3",
		  roles: [
			 { role: "dbOwner", db: dbName}
		  ]
		}
	);
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