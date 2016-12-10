from pymongo import MongoClient
from flask import Flask
import json
application = Flask(__name__)
#application.before_first_request(

database_name = 'predictvar'

# NOTE: I do not know how to create and hold open a Mongodb connection without
#       causing a problem with fork() after connect (call to MongoClient). The
#       warning seems to indicate that this is an unsafe situation and that
#       a connection to the database should not be shared over a fork
#       by independent processes, which makes sense. But I don't know how to
#       make it execute the MongoClient call once with the connection handle
#       in global scope, after uWSGI forks child processes, so that each one
#       of these functions does not need to create a new connection de novo
#       on every single hit. Anything in global scope in this script
#       seems to be executed prior to forking child servers. KONI 2016-07-02

# NOTE: An id query can currently only query an rsid because all we have
#       is a table (collection) of dbsnp records with the coordinate mappings
#       loaded. Other systematic identifiers (HGVS) may need to query a
#       different collection, on the basis that they don't begin with "rs"
#       perhaps, or we need to generalize what is currently the dbsnp
#       collection to something that is just a generic id to coordinate
#       lookup. KONI 2016-07-02
#@application.route("/variant/id/<rsid>")
@application.route("/variant/rsid/<rsid>/")
def by_rsid(rsid):
    results = []
    client = MongoClient('127.0.0.1')
    db = client[database_name]

    rsid_q = db.dbsnp.find({'rsid': rsid})
    for snp in rsid_q:
        query = db.variants.find({'chm': snp['chm'], 'pos': int(snp['pos']), 'alt': snp['alt']})
        for obj in query:
            del obj['_id']
            results.append(json.dumps(obj))


    return '{ "n_results": "%d", "results": [%s]}' % (len(results), ",".join(results)), 200, { 'Content-Type': 'application/json' }

@application.route("/variant/position/<chm>/<int:pos>/")
@application.route("/variant/position/<chm>/<int:pos>/<alt>/")
def variant(chm,pos,alt=None):
    results = []
    client = MongoClient('127.0.0.1')
    db = client[database_name]

    query = None
    if alt != None:
        query = db.variants.find({'chm': chm, 'pos': pos, 'alt': alt})
    else:
        query = db.variants.find({'chm': chm, 'pos': pos})
        
    for obj in query:
        del obj['_id']
        results.append(json.dumps(obj))
    
    return '{ "n_results": "%d", "results": [%s]}' % (len(results), ",".join(results)), 200, { 'Content-Type': 'application/json' }

# KONI 2016-07-02
# Executed only if this "script" is run directly from the command line
# activating the Flask internal web server and debugging mode, on
# port 5000. As per Flask docs this should never be done on a
# production server as it can allow someone to execute arbitrary
# python code, and as per host="0.0.0.0", it will allow connection
# from anywhere. Change this, if your debug/dev environment can use just
# localhost for this.
#
# When this script is passed to uWSGI as the module or whatever it is properly called
# (don't quite understand this yet), this below is not run. The above
# is just compiled and loaded with the decoraters directly Flask/uWSGI how to
# direct the URLs being hit (as coming in from nginx) to actual python code (above)
#
# The stack is presently
# http client <-> internet <-> us <-> nginx <-> uWSGI <-> Flask <-> this code <-> mongodb
if __name__ == "__main__":
    application.run(host="0.0.0.0",debug=True)
