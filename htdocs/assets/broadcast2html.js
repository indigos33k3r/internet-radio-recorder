// sadly embedding this into broadcast2html.xslt doesn't work for Opera -
// the 'if( now < dtstart )' ends up html escaped...

function amendClickableURLsInHTML(html) {
  // inspired by http://stackoverflow.com/a/3809435
  // Does not pick up naked domains, because they're hard to distinguish from domains in email addresses (see below).
  // Also requires a 2-4 character TLD, so the new 'hip' domains fail.
  var pat = /[-_.a-z0-9]{2,256}\.[a-z]{2,4}(?:\/[a-z0-9:%_\+.~#?&\/=]*)?/;
  var url_pat = new RegExp(/([\s\(\/])/.source + '(' + /(?:http(s?):\/\/)?/.source + '(' + pat.source + ')' + ')', 'gi');
  html = html.replace(url_pat, '$1<a href="http$3://$4" class="magic">$2</a>');

  var pat1 = /[-a-z0-9%_\+.~#\/=]+@[-a-z0-9%_\+.~#?&\/=]{2,256}\.[a-z]{2,4}(?:\?[-a-z0-9:%_\+.~#?&\/=]*)?/;
  var mail_pat = new RegExp(/(?:mailto:)?/.source + '(' + pat1.source + ')', 'gi');
  html = html.replace(mail_pat, '<a href="mailto:$1?subject=' + encodeURI(document.location) + '" class="magic">$&</a>');
  return html;
}

function amendClickableURLs(element) {
  if( null == element )
    return;
  element.innerHTML = amendClickableURLsInHTML(element.innerHTML)
}
amendClickableURLs(document.getElementById('content'));

// moment.lang("de");
var canonical_url = ('' + window.location).replace(/(\.xml)?(\.gz)?(#.*)?$/,'');
{
  var x = document.querySelectorAll('.canonical-url');
  for(var i = x.length - 1; i >= 0; i--)
    x[i].textContent = canonical_url;
}
{
  var x = document.querySelectorAll('.base-url');
  for(var i = x.length - 1; i >= 0; i--)
    x[i].textContent = canonical_url.replace(/\/stations\/[^\/]+\/\d{4}\/\d{2}\/\d{2}\/(index|\d{4}%20.+)$/, '');
}

var canonical_path = window.location.pathname.replace(/\.xml$/,'');

var dtstart = moment( document.querySelectorAll("meta[name='DC.format.timestart']")[0].getAttribute('content') );
var dtend = moment( document.querySelectorAll("meta[name='DC.format.timeend']")[0].getAttribute('content') );
var now = moment();

{
  var clz = 'is_past';
  if( now < dtstart )
    clz = 'is_future';
  else if( now < dtend )
    clz = 'is_current';
  document.getElementsByTagName('html')[0].classList.add(clz);
}

console.log('display podcast links');
var podasts_json_url = canonical_path + '.json';
var httpRequest = new XMLHttpRequest();
httpRequest.onreadystatechange = function(data0) {
  if (httpRequest.readyState == 4) {
    if (httpRequest.status >= 200 && httpRequest.status < 300) {
			console.log('display mp3/enclosure dir link');
			var enclosure_mp3_url = canonical_path.replace(/\/stations\//,'/enclosures/') + '.mp3';
			var enclosure_dir_url = enclosure_mp3_url.replace(/[^\/]+$/,'');
			document.getElementById('enclosure_link').setAttribute('href', enclosure_dir_url);
			// next check the existence of the mp3:
			var http1 = new XMLHttpRequest();
			http1.onreadystatechange = function(data1) {
				if (http1.readyState == 4) {
					if (http1.status >= 200 && http1.status < 300) {
						console.log('Yikes, there is a mp3!');
						document.getElementsByTagName('html')[0].classList.add('has_enclosure_mp3');
						document.getElementById('enclosure_link').setAttribute('href', enclosure_mp3_url);
						document.getElementById('enclosure_link').setAttribute('title', "Download: Rechte Maustaste + 'Speichern unter...'");
						// document.querySelectorAll('#enclosure audio source')[0].setAttribute('src', enclosure_mp3_url);
						document.getElementById('enclosure').setAttribute('style', 'display:block');
					}
				}
			}
			http1.open('HEAD', enclosure_mp3_url);
			http1.send(null);

			// and also care about the other (recording etc.) buttons
			var data = JSON.parse(httpRequest.responseText);
			var has_ad_hoc = false;
			var names = data.podcasts.map( function(pc) {
				has_ad_hoc = has_ad_hoc || (pc.name == 'ad_hoc');
				return '<a href="../../../../../podcasts/' + pc.name + '/">' + pc.name + '</a>';
			});
			document.getElementById('podcasts').innerHTML = names.join(', ');
			if( names.length == 0 ) {
				;
			} else {
				// $( 'p#enclosure' ).attr('style', 'display:block');
				document.getElementsByTagName('html')[0].classList.add('has_podcast');
				if( has_ad_hoc ) {
					document.getElementById('ad_hoc_action').setAttribute('name', 'remove');
					document.getElementById('ad_hoc_submit').setAttribute('value', 'Nicht Aufnehmen');
				} else {
					document.getElementById('ad_hoc_submit').setAttribute('style', 'display:none');
				}
			}
		}
  }
}
httpRequest.open('GET', podasts_json_url);
httpRequest.send(null);

console.log('make date time human readable');
function timeFromTitle(selector, fmt) {
  var elems = document.querySelectorAll(selector);
  for(var i = elems.length - 1; i >= 0; i--)
    elems[i].textContent = moment( elems[i].getAttribute('title') ).format(fmt);
}
timeFromTitle('.moment_date_time', 'ddd D[.] MMM YYYY HH:mm');
timeFromTitle('.moment_date', 'ddd D[.] MMM YYYY');
timeFromTitle('.moment_time', 'HH:mm');

console.log('rewrite today/tomorrow links');
document.getElementById('prev_week').setAttribute('href', '../../../' + moment(dtstart).subtract(7, 'days').format() );
document.getElementById('yesterday').setAttribute('href', '../../../' + moment(dtstart).subtract(1, 'days').format() );
document.getElementById('tomorrow' ).setAttribute('href', '../../../' + moment(dtstart).add(1, 'days').format() );
document.getElementById('next_week').setAttribute('href', '../../../' + moment(dtstart).add(7, 'days').format() );

// todo: mark current station
// step 1: what is the current station?
// step 2: iterate all ul#whatsonnow li and mark the according on with class is_current

function finishAlldayCurrentEntry(a) {
  // a.removeClass('is_past').addClass('is_current').append( jQuery('<span/>').text('jetzt') );
   a.classList.remove('is_past');
   a.classList.add('is_current');
   var span = document.createElement('span');
   span.textContent = 'jetzt';
   a.appendChild(span);
}

console.log('add other broadcasts of the day (same station)');
var http2 = new XMLHttpRequest();
http2.onload = function() {
  // console.log('GET ' + http2.responseURL + ' ' + http2.status);
  if (http2.status >= 200 && http2.status < 400) {
    var parent = document.getElementById('allday');
    parent.removeChild(parent.firstChild);

    var hasRecording = false;
    var pastBC = null;
    var allA = new DOMParser().parseFromString(http2.responseText, 'text/html').getElementsByTagName('a');
    for(var i = 0; i < allA.length; i++) {
      var src = allA[i];
      var href = src.getAttribute('href');
      var me = document.createElement('a');
      me.textContent = src.textContent;
      var li = document.createElement('li');
      li.appendChild(me);

      // console.log(i + ' ' + href);
      if( '../' === href )                  // ignore parent link
        continue;
      if( hasRecording )                                        // previous entry was a .json recording marker
        me.classList.add('has_podcast');
      if( hasRecording = href.endsWith('.json') ) // remember and swallow .json
        continue;
      var txt = me.textContent.replace(/\.xml$/i, '');
      var ma = txt.match(/^(\d{2})(\d{2})\s+(.*?)$/);           // extract time and title
      if( ma ) {
        var t0 = dtstart.hours(ma[1]).minutes(ma[2]).seconds(0); // assumes same day
        me.getAttribute('title', t0.format());
        me.textContent = t0.format('HH:mm') + ' ' + ma[3];
        // set past/current/future class
        if( now < t0 ) {
          if(pastBC) {
            finishAlldayCurrentEntry(pastBC);
            pastBC = null;
          }
          me.classList.add('is_future');
        } else {
          pastBC = me;
          me.classList.add('is_past');
        }
      } else {
        me.textContent = txt;                                 // index usually.
      }
      me.setAttribute('href', href.replace(/\.xml$/i, '') );  // make canonical url
      parent.appendChild(li);
    }
    if( pastBC && now < dtstart.hours(24).minutes(0).seconds(0) )
      finishAlldayCurrentEntry(pastBC)
    parent.setAttribute('style', 'display:block');
  }
}
http2.open('GET', '.');
http2.send();
