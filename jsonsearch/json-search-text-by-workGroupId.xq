xquery version "3.0";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace sparql = "http://www.w3.org/2005/sparql-results#";

declare option output:method "json";
declare option output:media-type "application/json";

import module namespace http = "http://expath.org/ns/http-client" at "/http-client/http-client.xq";


declare function local:getSparqlQuery($workGroup_short_id) as xs:string {
    (: currently cannot get $expression_type_id passed into query string; so it is currently hard coded to librum1-prologus :)
let $query := xs:string('
    SELECT ?item ?topLevelExpression
    WHERE
    {
        <http://scta.info/resource/' || $workGroup_short_id || '> <http://scta.info/property/hasExpression> ?topLevelExpression .
        ?topLevelExpression <http://scta.info/property/hasStructureItem> ?item .
    }
    ')
    return $query
};



declare function local:render($node) {
    typeswitch($node)
        case text() return concat($node, ' ')
        case element(tei:p) return <p>{local:recurse($node)}</p>
        case element(tei:title) return <em>{local:recurse($node)}</em>
        case element(tei:name) return <span style="font-variant: small-caps">{local:recurse($node)}</span>
        case element(exist:match) return <span style="background-color: yellow;">{local:recurse($node)}</span>
        case element(tei:rdg) return ()
        case element(tei:bibl) return ()
        case element (tei:note) return ()
        default return local:recurse($node)
};

declare function local:recurse($node) {
    for $child in $node/node()
    return
        local:render($child)
};

(: main query :)
let $response-header := response:set-header("Access-Control-Allow-Origin", "*")
let $workGroup_short_id := request:get-parameter('workGroupId', 'sententiae')
let $url := "http://sparql-docker.scta.info/ds/query?query=",
$sparql := local:getSparqlQuery($workGroup_short_id),
$encoded-sparql := encode-for-uri($sparql),

$sparql-result := http:send-request(
   <http:request href="{concat($url, $encoded-sparql)}" method="get">
      <http:header name="accept" value="application/xml"/>
   </http:request>
)

(:return $sparql-result:)

  (: let $collection := '/db/apps/scta/'
let $documents := collection($collection)[tei:TEI] ! substring-after(base-uri(), 'db/apps/scta/')
let $withins := ('graciliscommentary/pg-b1q1/pg-b1q1.xml','graciliscommentary/pg-b1q6/pg-b1q6.xml')
let $documents-to-show := $documents[. = $withins] :)

return 
    map {
    "results": 
    
    for $result in $sparql-result//sparql:result
    let $url-array := fn:tokenize($result/sparql:binding[@name="item"]/sparql:uri/text(), "/")
    let $itemid := $url-array[last()]
    let $url-cid-array := fn:tokenize($result/sparql:binding[@name="topLevelExpression"]/sparql:uri/text(), "/")
    let $cid := $url-cid-array[last()]
    
    let $transcription := doc(concat('/db/apps/scta-data/', $cid, '/', $itemid, '/transcriptions.xml'))/transcriptions/transcription[1]
(:    let $doc := concat('/db/apps/scta-data/', $cid, '/', $itemid, '/', $itemid, '.xml'):)
    
    let $doc := if ($transcription) then 
                    concat('/db/apps/scta-data/', $cid, '/', $itemid, '/', $transcription)
                else
                    concat('/db/apps/scta-data/', $cid, '/', $itemid, '/', $itemid, '.xml')

    let $query := request:get-parameter('query', 'potentia')

    let $hits := doc($doc)//tei:p[ft:query(., $query)]
    
    
        
        for $hit in $hits
        let $pid := $hit/@xml:id/string()
        let $itemid := $hit/ancestor::tei:body/tei:div/@xml:id/string()
        let $itemtitle := $hit/preceding::tei:titleStmt/tei:title/string()
        let $itemauthor := $hit/preceding::tei:titleStmt/tei:author/string()
        
        return
            map{
                "pid": $pid,
                "text": local:render(util:expand($hit))
            }
    }
    