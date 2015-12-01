_.templateSettings = {
  evaluate: /\{\%(.+?)\%\}/g,
  interpolate: /\{\{(.+?)\}\}/g,
  escape: /\{-(.+?)-\}/g
}

var renderTemplate = function renderTemplate(templateName, data){
  data = data || {};
  var source = $('#' + templateName);
  if(source.length){
    return _.template(source.html())(data);
  } else {
    throw 'renderTemplate Error: Could not find source template with matching #' + templateName;
  }
}

var vote = function vote($choice){
  var $pairing = $choice.parents('.pairing');
  var incomingPersonID = $('.pairing__incoming .person', $pairing).attr('data-id');
  var vote = [];

  if($choice.is('.skip')) {
    // Insert a null value to indicate skip, these are removed when
    // serializing to CSV.
    window.votes.push( null );
  } else {
    window.votes.push( [incomingPersonID, $choice.attr('data-uuid')] );
  }

  $pairing.hide();
  if($pairing.next().length){
    $pairing.next().show();
  } else {
    showOrHideCSV();
  }
  updateProgressBar();
  updateUndoButton();
}

var updateProgressBar = function updateProgressBar(){
  var progress = window.votes.length / $('.pairing').length * 100;
  $('.progress-bar div').animate({
    width: '' + progress + '%'
  }, 100);
}

var generateCSV = function generateCSV(){
  return Papa.unparse({
    fields: ['id', 'uuid'],
    data: window.reconciled.concat(_.compact(window.votes))
  });
}

var showOrHideCSV = function showOrHideCSV(){
  var $csv = $('.csv');
  if($csv.is(':visible')){
    $csv.slideUp(100);
  } else {
    $csv.val(generateCSV());
    $csv.slideDown(100, function(){
      $csv.select();
    });
    $(document).on('click.dismiss-csv', function(){
        $csv.slideUp(100);
        $(document).off('click.dismiss-csv');
    });
  }
}

var undo = function undo(){
  // Only continue if there's actually something to undo.
  if(window.votes.length == 0){ return; }

  // Remove last vote from window.votes,
  // and re-show the most recently hidden pairing.
  var undoneVote = window.votes.pop();
  $('.pairing:visible').hide().prev().show();

  // Update the various bits of UI.
  updateProgressBar();
  updateUndoButton();
}

var updateUndoButton = function updateUndoButton(){
  if(window.votes.length == 0){
    $('.undo').addClass('disabled');
  } else {
    $('.undo').removeClass('disabled');
  }
}

jQuery(function($) {
  if(matches.length == 0){
    $('.messages').append('<h1>Nothing to reconcile!</h1>');
    $('.progress-bar div').animate({
      width: '100%'
    }, 500);
    updateUndoButton();
  }

  $.each(matches, function(i, match) {
    var incomingPerson = match.incoming;
    var existingPerson = match.existing[0][0];

    // Skip exact matches for now
    if (incomingPerson[incomingField].toLowerCase() == existingPerson[existingField].toLowerCase()) {
      return;
    }
    var incomingPersonFields = _.filter(Object.keys(incomingPerson), function(field) {
      return incomingPerson[field];
    });
    var existingPersonHTML = _.map(match.existing, function(existing) {
      var person = existing[0];
      var fields = _.intersection(incomingPersonFields, Object.keys(person));
      return renderTemplate('person', { person: person, field: existingField, fields: fields });
    });

    var fields = match.existing.map(function(existing) {
      var person = existing[0];
      return Object.keys(person);
    });

    var commonFields = _.intersection(incomingPersonFields, _.uniq(_.flatten(fields)));

    var html = renderTemplate('pairing', {
      existingPersonHTML: existingPersonHTML.join("\n"),
      incomingPersonHTML: renderTemplate('person', {
        person: incomingPerson,
        field: incomingField,
        fields: commonFields
      })
    });
    $('.pairings').append(html);
  });

  $('.pairing').eq(0).nextAll().hide();

  updateUndoButton();
  updateProgressBar();

  $(document).on('click', '.pairing__choices > div', function(){
    vote($(this));
  });

  $(document).on('keydown', function(e){
    if(e.which == 39){
      var $choice = $('.pairing:visible .skip');
      vote($choice);
    } else if(e.which > 48 && e.which < 58){
      var $choice = $('.pairing:visible .pairing__choices .person').eq(e.which - 49);
      vote($choice);
    } else if(e.keyCode == 27){
      showOrHideCSV();
    } else if(e.keyCode == 90 && (e.metaKey || e.ctrlKey)){
      undo();
    }
  });

  $('.undo').on('click', function(){
    undo();
  });

  $('.export-csv').on('click', function(e){
    e.stopPropagation();
    showOrHideCSV();
  });

  $('.csv').on('click', function(e){
    e.stopPropagation();
  }).on('focus', function(){
    $(this).select();
  });
});
