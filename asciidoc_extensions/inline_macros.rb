require 'asciidoctor/extensions' unless RUBY_ENGINE == 'opal'

include Asciidoctor

# An inline macro that turns github:foo/bar into a link to foo/bar on github.
#
# Usage
#
#   github:foo/bar[]    -> https://github.com/user/project(GH)
#   github:foo/bar[Bar] -> Bar(GH)
#
class GitHubMacro < Extensions::InlineMacroProcessor
  use_dsl

  named :github
  parse_content_as :text

  def process parent, target, attrs
    url = %(https://github.com/#{target})
    if (text = attrs['text']).empty?
      text = target
    end
    text = text + 'image:https://github.com/favicon.ico[GitHub,14,14]'
    (create_anchor parent, text, type: :link, target: url).render 
  end
end

# An inline macro that turns man:function[section] into a link to man7.org.
#
# Usage
#
#   man:bash[2] -> https://man7.org/linux/man-pages/man1/bash.1.html(Linux)
#
class ManMacro < Extensions::InlineMacroProcessor
  use_dsl

  named :man
  parse_content_as :text
  resolve_attributes '1:section'

  def process parent, target, attrs
    section = attrs['section']
    url = %(https://man7.org/linux/man-pages/man#{section}/#{target}.#{section}.html)
    text = %(#{target}(#{section}))
    text = text + 'image:https://www.kernel.org/theme/images/logos/favicon.png[Linux,14,14]'
    (create_anchor parent, text, type: :link, target: url).render 
  end
end

# An inline macro that defines a sidenote reference number.
#
# Usage
#
#   sidenote:ref[] -> ^[N]^
#   sidenote:def[] -> [N]:
#
class SidenoteMacro < Extensions::InlineMacroProcessor
  use_dsl

  named :sidenote

  def process parent, target, attrs
    if target == 'ref' then
      sidenum = parent.document.counter '_side_ref'
      text = "^[#{sidenum}]^"
      type = :superscript
      anchor = "[[_sideref_#{sidenum}]]"
      text = anchor + text
    elsif target == 'def' then
      sidenum = parent.document.counter '_side_def'
      text = "[[_sidedef_#{sidenum}]][#{sidenum}]:"
    else
      raise "unknown target #{target}"
    end

    create_inline_pass parent, text, attributes: {'subs' => :normal}
  end
end

# An inline macro that defines a callout number.
#
# Usage
#
#   conum:[1] -> [1]
#
class ConumMacro < Extensions::InlineMacroProcessor
  use_dsl

  named :conum

  def process parent, target, attrs
    text = %(<i class="conum" data-value="#{target}"></i>)
    create_inline_pass parent, text
  end
end

Asciidoctor::Extensions.register do
  inline_macro GitHubMacro
  inline_macro ManMacro
  inline_macro SidenoteMacro
  inline_macro ConumMacro
end
