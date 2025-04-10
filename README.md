# my_youtube_caption_scraper

var scroll = setInterval(function(){ window.scrollBy(0, 1000)}, 1000);

urls = $$('a'); urls.forEach(function(v,i,a){if (v.id=="video-title-link"){console.log('\t'+v.title+'\t'+v.href+'\t')}});