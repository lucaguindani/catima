init = ->
  $("[data-provider='summernote']").summernote
    height: 300
    maximumImageFileSize: 262144 # 256KB
    codeviewFilter: false # allow all html tags (script and script tags)
    callbacks: onBlurCodeview: -> $(this).val $(this).summernote('code') # Fix content not saved from codeview issue
    toolbar: [
      ['style', ['style']],
      ['font', ['bold', 'italic', 'underline', 'clear']],
      ['fontname', ['fontname']],
      ['color', ['color']],
      ['para', ['ul', 'ol', 'paragraph']],
      ['table', ['table']],
      ['insert', ['link', 'picture', 'video']],
      ['view', ['fullscreen', 'codeview', 'help']],
    ]

$(document).ready(init)
