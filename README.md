# Salesforce Apex Abstract DataAccess class

Extend this class for any sObject. Best way I know to implement - extend and create private static singleton instance, and expose public static methods that convert results into the appropriate object.

It will maintain a cache after the first query, and you have a choice whether to retrieve the cache or reset the cache in future method calls.

