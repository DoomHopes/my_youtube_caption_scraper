# my_youtube_caption_scraper

var scroll = setInterval(function(){window.scrollBy({top:1000,left:0,behavior:'smooth'})},1000);

urls = $$('a'); urls.forEach(function(v,i,a){if (v.id=="video-title-link"){console.log('\t'+v.title+'\t'+v.href+'\t')}});