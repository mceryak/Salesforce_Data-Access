public inherited sharing abstract class DataAccess {

    /***************************************
     * static vars/methods
     ***************************************/

    // to make sure that we only have one instance per sObject
    @TestVisible
    private static Set<String> instances;

    static {
        instances = new Set<String>();
    }

    /***************************************
     * instance vars
     ***************************************/

    // sObject we get data for
    private Schema.SObjectType sObjectType;
    private String sObjectTypeName { get { return this.sObjectType?.getDescribe().getName(); }}

    // record Id -> record
    @TestVisible
    private Map<Id, sObject> recordMapCache;
    // query method number -> cached inSet values for that query
    private Map<Integer, Set<String>> queryCache;

    // constructor
    protected DataAccess(Schema.sObjectType objectType) {
        if (objectType == null) { throw new DataAccessException('must pass in an sObject'); }
        if (instances.contains(objectType.getDescribe().getName())) { throw new DataAccessException('an instance for this sObject already exists.'); }
        DataAccess.instances.add(objectType.getDescribe().getName());
        this.sObjectType = objectType;
        this.recordMapCache = new Map<Id, sObject>();
        this.queryCache = new Map<Integer, Set<String>>();
        // system.debug('++++ object name = ' + this.sObjectType.getDescribe().getName() + ', trigger object =  ' + TriggerHandler.currentlyExecutingHandler.sObjectType.getDescribe().getName());
    }


    /***************************************
     * overrideable methods
     ***************************************/

    // at least one query method must be overridden
    protected abstract List<sObject> doQuery0(Set<String> inSet);
    // field name for required doQuery defaults to 'Id', but can be overridden
    protected virtual String query0IdFieldName() { return 'Id'; }

    // add more query methods as needed
    protected virtual List<sObject> doQuery1(Set<String> inSet) { throw new DataAccessException('this doQuery method has not been implemented1'); }
    protected virtual List<sObject> doQuery2(Set<String> inSet) { throw new DataAccessException('this doQuery method has not been implemented2'); }
    protected virtual List<sObject> doQuery3(Set<String> inSet) { throw new DataAccessException('this doQuery method has not been implemented3'); }

    protected virtual String query1IdFieldName() { throw new DataAccessException('this queryIdFieldName method has not been implemented1'); }
    protected virtual String query2IdFieldName() { throw new DataAccessException('this queryIdFieldName method has not been implemented2'); }
    protected virtual String query3IdFieldName() { throw new DataAccessException('this queryIdFieldName method has not been implemented3'); }

    /***************************************
     * instance methods
     ***************************************/

    // dynamically calls the correct doQuery method based on given input
    private List<sObject> callDoQuery(Integer queryNum, Set<String> ids) {
        switch on queryNum {
            when 0 { return doQuery0(ids); }
            when 1 { return doQuery1(ids); }
            when 2 { return doQuery2(ids); }
            when 3 { return doQuery3(ids); }
            when else { throw new DataAccessException('invalid query number: ' + queryNum); }
        }
    }

    // dynamically grabs the correct field name based on given input
    private String getIdFieldName(Integer queryNum) {
        switch on queryNum {
            when 0 { return query0IdFieldName(); }
            when 1 { return query1IdFieldName(); }
            when 2 { return query2IdFieldName(); }
            when 3 { return query3IdFieldName(); }
            when else { throw new DataAccessException('invalid query number: ' + queryNum); }
        }
    }

    // if this query has been run already in this transaction, then checks if it has cached the ids
    @TestVisible
    private Boolean isCached(Set<String> inSet, Integer queryNum) {
        return this.queryCache.get(queryNum)?.containsAll(inSet) == true;
    }

    // converts set<id> into set<string> then calls the main record retrieval method
    @TestVisible
    protected Map<Id, sObject> getMap(Set<Id> inSet, Integer queryNum, Boolean returnCache) {
        return getMap((Set<String>)JSON.deserialize(JSON.serialize(inSet), Set<String>.class), queryNum, returnCache);
    }

    /**
     * primary record retrieval method
     * @param  inSet       set of either Ids or unique fields (i.e. developername). 
     * @param  queryNum    corresponds to the appropriate doQuery method that will be called
     * @param  returnCache do we want to return what's in the cache if it exists?
     * @return             sObject Map of Id -> record
     */ 
    protected Map<Id, sObject> getMap(Set<String> inSet, Integer queryNum, Boolean returnCache) {
        // check in cache if user wants cached values
        if (returnCache && this.isCached(inSet, queryNum)) {
            return getCastedSubMap(inSet, this.recordMapCache.values(), getIdFieldName(queryNum));
        }
        // update query cache with new id values
        this.updateQueryCache(queryNum, inSet);
        // put queried records in the record cache and return desired subset
        this.recordMapCache.putAll(this.callDoQuery(queryNum, inSet));
        return getCastedSubMap(inSet, this.recordMapCache.values(), this.getIdFieldName(queryNum));
    }

    // updates the query cache with new values
    private void updateQueryCache(Integer queryNum, Set<String> inSet) {
        if (this.queryCache.containsKey(queryNum)) {
            this.queryCache.get(queryNum).addAll(inSet);
        } else {
            this.queryCache.put(queryNum, new Set<String>(inSet));
        }
    }

    // casts to the appropriate sObject and returns the requested subset of the cache. if subSetIds is null, then return all (i.e. useful for servicecode/worktype)
    private Map<Id, sObject> getCastedSubMap(Set<String> requestedIds, List<sObject> fullList, String idField) {
        Map<Id, sObject> subMap = (Map<Id, sObject>)Type.forName('Map<Id,' + this.sObjectTypeName + '>').newInstance();
        for (sObject so : fullList) {
            if (requestedIds == null || requestedIds.contains((String)so.get(idField))) {
                subMap.put(so.Id, so);
            }
        }
        return subMap;
    }

    private void clearCache() {
        this.recordMapCache.clear();
        this.queryCache.clear();
    }


    // exception class
    public class DataAccessException extends Exception {}

}