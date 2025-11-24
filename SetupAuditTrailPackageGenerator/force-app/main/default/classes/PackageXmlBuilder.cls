public with sharing class PackageXmlBuilder {

    // Internal DTO to group members by type
    private class TypeMembers {
        String typeName;
        Set<String> members = new Set<String>();
    }

    /**
     * @description
     * Builds a package.xml string from a list of MetadataItem objects.
     *
     * @param metadataItems List of metadata components to include.
     * @param apiVersion    API version to use (e.g., '60.0').
     * @return package.xml content as a String
     */
    public static String buildPackageXml(
        List<MetadataItem> metadataItems,
        String apiVersion
    ) {
        Map<String, TypeMembers> groupedTypes = new Map<String, TypeMembers>();

        for (MetadataItem item : metadataItems) {
            if (String.isBlank(item.typeName) || String.isBlank(item.memberName)) continue;

            if (!groupedTypes.containsKey(item.typeName)) {
                TypeMembers tm = new TypeMembers();
                tm.typeName = item.typeName;
                groupedTypes.put(item.typeName, tm);
            }
            groupedTypes.get(item.typeName).members.add(item.memberName);
        }

        String xmlOutput = '';
        xmlOutput += '<?xml version="1.0" encoding="UTF-8"?>\n';
        xmlOutput += '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n';

        List<TypeMembers> sortedTypes = groupedTypes.values();
        sortedTypes.sort(new TypeMembersComparator());

        for (TypeMembers tm : sortedTypes) {
            xmlOutput += '    <types>\n';
            List<String> sortedMembers = new List<String>(tm.members);
            sortedMembers.sort();

            for (String member : sortedMembers) {
                xmlOutput += '        <members>' + String.escapeSingleQuotes(member) + '</members>\n';
            }

            xmlOutput += '        <name>' + String.escapeSingleQuotes(tm.typeName) + '</name>\n';
            xmlOutput += '    </types>\n';
        }

        xmlOutput += '    <version>' + String.escapeSingleQuotes(apiVersion) + '</version>\n';
        xmlOutput += '</Package>';

        return xmlOutput;
    }

    // Comparator class for sorting TypeMembers by typeName
    private class TypeMembersComparator implements Comparator<TypeMembers> {
        public Integer compare(TypeMembers tm1, TypeMembers tm2) {
            return tm1.typeName.compareTo(tm2.typeName);
        }
    }
}