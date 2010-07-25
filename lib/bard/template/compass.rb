run "compass init rails . --sass-dir=app/stylesheets --css-dir public/stylesheets"

file "app/stylesheets/application.sass", <<-END
@import "constant"

@import "blueprint"
@import "compass/reset"
@import "compass/utilities"
@import "compass/layout"
 
=blueprint($body_selector = "body")
  +blueprint-typography($body_selector)
  +blueprint-utilities
  +blueprint-debug
  +blueprint-interaction
  +blueprint-colors
  
@import "general"
END

file "app/stylesheets/_constant.sass", <<-END
$blueprint_grid_columns: 24
$blueprint_grid_width: 30px
$blueprint_grid_margin: 10px

$primaryColor: blue

=box-shadow( $blur, $color )
  -moz-box-shadow: 0px 0px $blur $color
  -webkit-box-shadow: 0px 0px $blur $color
=text-shadow($px, $color)
  text-shadow: 0px 0px $px $color
=border-radius( $radius )
  -moz-border-radius: $radius
  -webkit-border-radius: $radius
  border-radius: $radius
=border-radius-specific( $location1, $location2, $radius )
  -moz-border-radius-\#{$location1}\#{$location2}: $radius
  -webkit-border-\#{$location1}-\#{$location2}-radius: $radius
  border-\#{$location1}-\#{$location2}-radius: $radius
END

file "app/stylesheets/_general.sass", <<-END
body
  font: 13px normal Arial, sans-serif
  color: #373737

.bold, b, strong
  font-weight: bold

a
  text-decoration: none
  color: $primaryColor
  img
    border: 1px solid transparent

p
  margin: 12px 0
  line-height: 1.4
  text-align: justify

ul, ol, li
  margin: 0
  padding: 0

h1, h2, h3, h4, h5, h6
  margin: 0
  padding: 0

h2, h3, h4
  text-transform: uppercase

h2, h3
  color: black

h2
  font: 2em bold "Arial Black"
  line-height: 1
  a
    color: black
    &:hover
      color: $primaryColor

h3
  font-weight: bold
  font-size: 1.1em

h4
  font-size: 0.9em
  border-bottom: 1px solid #3f3f3f
  color: #3f3f3f
  margin-bottom: 9px

// tables

table
  border-collapse: none
  margin-bottom: 6px
  tr.even
    background: #ebebeb
  td
    line-height: 1.25
    vertical-align: top

// forms

.field
  margin: 0px 0 10px

label
  display: inline-block
  width: 120px
  text-align: right
  margin-right: 9px
  &.reqd
    font-weight: bold
    font-style: normal
  &.opt
    color: #666666

select
  width: 130px

input, select
  &.sm
    width: 60px
  &.lg
    width: 407px
  &+label
    width: auto
    margin-left: 9px
  &.radio
    &+label
      font-size: 1em
      text-transform: inherit
      color: #242424
      margin-left: 0
END

run "compass compile"
