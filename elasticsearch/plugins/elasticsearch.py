#!/usr/bin/env python
import sys
import requests
import collections

"""
Hit up the nodes stats url and pull back all the metrics for that node
TODO: clean up some of the kv pairs coming back and exclude the non-numeric
values (some come back as mb and have a byte equiv key
"""
HOST = 'localhost'
PORT = 9200
BASE_URL = "http://%s:%s" % (HOST, PORT)
LOCAL_URL = "/_nodes/_local"
HEALTH_URL = "/_cluster/health"

# Choose the elasticsearch stats to return
# Any of settings,os,process,jvm,thread_pool,network,transport,http,plugins
# OR leave empty for all statistics
STATS = ""
STATS_URL = "/_nodes/_local/stats/%s" % STATS
CLUSTER_STATS_URL = "/_cluster/stats"

def _get_es_stats(url):
    """ Get the node stats
    """
    data = requests.get(url)
    if data.status_code == 200:
        stats = data.json()
        return stats
    else:
        raise Exception("Cannot get Elasticsearch version")


def flatten(d, parent_key='', sep='.'):
    """ flatten a dictionary into a dotted string
    """
    items = []
    for key, value in d.items():
        new_key = parent_key + sep + key if parent_key else key
        if isinstance(value, collections.MutableMapping):
            items.extend(flatten(value, new_key, sep=sep).items())
        else:
            items.append((new_key, value))
    return dict(items)

exit_code = 0
try:
    es_stats = flatten(_get_es_stats(BASE_URL + STATS_URL))
    es_health = flatten(_get_es_stats(BASE_URL + HEALTH_URL))
    cluster_stats = flatten(_get_es_stats(BASE_URL + CLUSTER_STATS_URL))

    perf_data = "OK | "
    for k, v in es_stats.iteritems():
        if str(v)[0].isdigit():
            k = k.rsplit('.')[2::]
            perf_data += '.'.join(k) + '=' + str(v) + ';;;; '

    for k, v in es_health.iteritems():
        if str(v)[0].isdigit():
            perf_data += str(k) + "=" + str(v) + ';;;; '

    if es_health['status'] == 'green':
        exit_status = 0
    elif es_health['status'] == 'yellow':
        exit_status = 1
    elif es_health['status'] == 'red':
        exit_status = 2

    for k, v in cluster_stats.iteritems():
        if str(v)[0].isdigit():
            perf_data += str(k) + "=" + str(v) + ';;;; '


    print(perf_data)
    sys.exit(exit_code)

except Exception as e:
    print("Plugin Failed! Exception: " + str(e))
    sys.exit(2)