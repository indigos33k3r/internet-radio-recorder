// sadly embedding this into broadcast2html.xslt doesn't work for Opera - 
// the 'if( now < dtstart )' ends up html escaped...

// moment.lang("de");
$('#my-url').text( window.location );

var dtstart = new Date( $("meta[name='DC.format.timestart']").attr("content") );
var dtend = new Date( $("meta[name='DC.format.timeend']").attr("content") );
var now = new Date();
if( now < dtstart )
  $( 'html' ).addClass('is_future');
else if( now < dtend )
  $( 'html' ).addClass('is_current');
else
  $( 'html' ).addClass('is_past');

// display podcast links
var podasts_json_url = window.location.pathname.replace(/^.*\//,'').replace(/\.xml$/,'.json');
$.ajax({ url: podasts_json_url, cache: true, dataType: 'json' }).done( function( data ) {
  // display mp3/enclosure dir link
  var enclosure_dir_url = window.location.pathname.replace(/\/stations\//,'/enclosures/').replace(/[^\/]+\.xml$/,'');
  $( 'a#enclosure_link' ).attr('href', enclosure_dir_url);
  var enclosure_mp3_url = window.location.pathname.replace(/\/stations\//,'/enclosures/').replace(/\.xml$/,'.mp3');
  $.ajax({ url: enclosure_mp3_url, type: 'HEAD', cache: true, }).done( function() {
    $( 'html' ).addClass('has_enclosure_mp3');
    $( 'a#enclosure_link' ).attr('href', enclosure_mp3_url);
    $( '#enclosure audio source' ).attr('src', enclosure_mp3_url);
    $( '#enclosure' ).attr('style', 'display:block');
  });
  var has_ad_hoc = false;
  var names = data.podcasts.map( function(pc) {
    has_ad_hoc = has_ad_hoc || (pc.name == 'ad_hoc');
    return '<a href="../../../../../podcasts/' + pc.name + '/">' + pc.name + '</a>';
  } );
  $( '#podcasts' ).html( names.join(', ') );
  if( names.length == 0 ) {
    ;
  } else {
    $( 'p#enclosure' ).attr('style', 'display:block');
    $( 'html' ).addClass('has_podcast');
    if( has_ad_hoc ) {
      $( '#ad_hoc_action' ).attr('name', 'remove');
      $( '#ad_hoc_submit' ).attr('value', 'Nicht Aufnehmen');
    } else {
      $( '#ad_hoc_submit' ).attr('style', 'display:none');
    }
  }
});

// make date time display human readable
$( '#dtstart' ).html( moment(dtstart).format('ddd D[.] MMM YYYY HH:mm') );
$( '#dtend' ).html( moment(dtend).format('HH:mm') );

// add html linebreaks to description
var t = $("meta[name='DC.description']").attr("content");
try {
  // escape for xml/html
  t = t.replace(/&/g, "&amp;");
  t = t.replace(/</g, "&lt;");
  t = t.replace(/>/g, "&gt;");
  // linefeeds
  t = t.replace(/\n/g, "<br/>\n");
  $( '#content' ).html( t );
} catch(e) {
  $( '#content' ).text( 'Aua: "' + e + '": ' + t );
}

// add today/tomorrow links
{
  var prev_week = new Date(dtstart.getTime() - 7*24*60*60*1000).toISOString().replace(/\.000Z/,'+00:00')
  $( '#prev_week' ).attr('href', '../../../../../app/now.lua?t=' + prev_week );
}{
  var yesterday = new Date(dtstart.getTime() - 24*60*60*1000).toISOString().replace(/\.000Z/,'+00:00')
  $( '#yesterday' ).attr('href', '../../../../../app/now.lua?t=' + yesterday );
}{
  var tomorrow = new Date(dtstart.getTime() + 24*60*60*1000).toISOString().replace(/\.000Z/,'+00:00')
  $( '#tomorrow' ).attr('href', '../../../../../app/now.lua?t=' + tomorrow );
}{
  var next_week = new Date(dtstart.getTime() + 7*24*60*60*1000).toISOString().replace(/\.000Z/,'+00:00')
  $( '#next_week' ).attr('href', '../../../../../app/now.lua?t=' + next_week );
}

// add all day broadcasts
$.ajax({ url: window.location.pathname + '/..', type: 'GET', cache: true, }).done( function(xmlBody) {
  var hasRecording = false;
  var allLinks = $( $.parseXML( xmlBody ) ).find( "a[href $= '.xml'], a[href $= '.json']" ).map( function() {
    var me = $(this);
    var txt = me.text().replace(/^(\d{2})(\d{2})\s+(.*)(\.xml)$/, '$1:$2 $3');
    if( hasRecording )
      me.addClass('has_podcast');
    if( hasRecording = me.attr("href").search(/\.json$/i) >= 0 )
      return null;
    me.text( txt );
    return this;
  });
  $( '#allday' ).html( allLinks );
  $( '#allday a' ).wrap("<li>");
  $( '#allday' ).show();
});

// add stream url
$.ajax({ url: '../../../app/station.cfg', type: 'GET', cache: true, }).done( function(luaCfg) {
  var stream_url = luaCfg.match( /(stream_url)\s*=\s*'([^']*)'/ );
  if( stream_url )
    $( '#stream' ).attr( 'href', stream_url[2] ).show();
});
