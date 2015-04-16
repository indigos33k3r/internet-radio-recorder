// sadly embedding this into broadcast2html.xslt doesn't work for Opera - 
// the 'if( now < dtstart )' ends up html escaped...

// moment.lang("de");
var canonical_url = ('' + window.location).replace(/\.xml$/,'');
$('#my-url').text( canonical_url );

var canonical_path = window.location.pathname.replace(/\.xml$/,'');
var dtstart = moment( $("meta[name='DC.format.timestart']").attr("content") );
var dtend = moment( $("meta[name='DC.format.timeend']").attr("content") );
var now = moment();
if( now < dtstart )
  $( 'html' ).addClass('is_future');
else if( now < dtend )
  $( 'html' ).addClass('is_current');
else
  $( 'html' ).addClass('is_past');

// display podcast links
var podasts_json_url = canonical_path + '.json';
$.ajax({ url: podasts_json_url, cache: true, dataType: 'json' }).done( function( data ) {
  // display mp3/enclosure dir link
  var enclosure_mp3_url = canonical_path.replace(/\/stations\//,'/enclosures/') + '.mp3';
  var enclosure_dir_url = enclosure_mp3_url.replace(/[^\/]+$/,'');
  $( 'a#enclosure_link' ).attr('href', enclosure_dir_url);
  $.ajax({ url: enclosure_mp3_url, type: 'HEAD', cache: true, }).done( function() {
    $( 'html' ).addClass('has_enclosure_mp3');
    $( 'a#enclosure_link' ).attr('href', enclosure_mp3_url);
    $( 'a#enclosure_link' ).attr('title', "Download: Rechte Maustaste + 'Speichern unter...'");
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

// add today/tomorrow links
$( '#prev_week' ).attr('href', '../../../' + moment(dtstart).subtract('days', 7).format() );
$( '#yesterday' ).attr('href', '../../../' + moment(dtstart).subtract('days', 1).format() );
$( '#tomorrow'  ).attr('href', '../../../' + moment(dtstart).add('days', 1).format() );
$( '#next_week' ).attr('href', '../../../' + moment(dtstart).add('days', 7).format() );

// add all day broadcasts
$.ajax({ url: '.', type: 'GET', cache: true, dataType: 'xml', }).done( function(xmlBody) {
  var hasRecording = false;
  var allLinks = $(xmlBody).find('a').map( function() {
    var me = $(this);
    var txt = me.text();
    if( 'Parent Directory' == txt )
      return null;
    txt = txt.replace(/^(\d{2})(\d{2})\s+(.*?)(\.xml)?$/, '$1:$2 $3');
    if( hasRecording )
      me.addClass('has_podcast');
    if( hasRecording = me.attr("href").search(/\.json$/i) >= 0 )
      return null;
    me.attr('href', me.attr('href').replace(/\.xml$/, '') );
    me.text( txt );
    return this;
  });
  $( '#allday' ).html( allLinks );
  $( '#allday a' ).wrap("<li>");
  $( '#allday' ).show();
});

// add whatsonnow station list
$.ajax({ url: '../../../..', type: 'GET', cache: true, dataType: 'xml', }).done( function(xmlBody) {
  // scan all stations/*/
  var allStations = $(xmlBody).find( "a[href $= '/']" ).map( function() {
    var me = $(this);
    var url_ = me.attr('href');
    if( url_.match(/^\.\.\/$/) )
      return null;
    me.attr('href', '../../../../' + url_.replace(/\/$/,'') + '/now');
 
    $.ajax({ url: me.attr('href'), type: 'GET', cache: true, dataType: 'xml', }).done( function(xmlBody) {
      var title = $(xmlBody).find("meta[name = 'DC.title']").attr('content');
      //me.html('<span class="station">' + me.html() + '</span>' );
      me.wrapInner('<span class="station">');
      if( title )
        me.append('<br class="br"/>', '<span class="broadcast">' + title + '</span>' );
    }).fail( function() {
      // disable broken hrefs
      me.attr('href', null);
    });

    return this;
  });
  $( '#whatsonnow' ).html( allStations );
  $( '#whatsonnow a' ).wrap("<li class='border'>");
});

