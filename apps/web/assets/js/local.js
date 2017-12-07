function pageReady( jQuery ) {
    // Code to run when the document is ready.
}

function pageFullyLoaded() {
  var masthead = $( "#masthead-text" );

  setTimeout(function(){
        masthead.attr("class", "text-ready");
    }, 1000);

}

$( window ).on( "load", pageFullyLoaded );
