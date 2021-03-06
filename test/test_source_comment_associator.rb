# frozen_string_literal: true

require 'helper'
require 'parser/ruby18'

class TestSourceCommentAssociator < Minitest::Test
  def parse_with_comments(code)
    parser = Parser::Ruby18.new

    buffer = Parser::Source::Buffer.new('(comments)')
    buffer.source = code

    parser.parse_with_comments(buffer)
  end

  def associate(code)
    ast, comments = parse_with_comments(code)
    associations  = Parser::Source::Comment.associate(ast, comments)

    [ ast, associations ]
  end

  def associate_locations(code)
    ast, comments = parse_with_comments(code)
    associations  = Parser::Source::Comment.associate_locations(ast, comments)

    [ ast, associations ]
  end

  def test_associate
    ast, associations = associate(<<-END)
#!/usr/bin/env ruby
# coding: utf-8
# class preceding
# another class preceding
class Foo # class keyword line
  # method foo preceding
  def foo
    puts 'foo'
  end # method foo decorating
  # method bar preceding
  def bar
    # expression preceding
    1 + # 1 decorating
      2
    # method bar sparse
  end # method bar decorating
  # class sparse
end # class decorating
    END

    klass_node      = ast
    klass_name_node = klass_node.children[0]
    foo_node        = klass_node.children[2].children[0] # def foo
    bar_node        = klass_node.children[2].children[1] # def bar
    expr_node       = bar_node.children[2] # 1 + 2
    one_node        = expr_node.children[0] # 1

    assert_equal 6, associations.size
    assert_equal [
      '# class preceding',
      '# another class preceding',
      '# class sparse',
      '# class decorating'
    ], associations[klass_node].map(&:text)
    assert_equal [
      '# class keyword line'
    ], associations[klass_name_node].map(&:text)
    assert_equal [
      '# method foo preceding',
      '# method foo decorating'
    ], associations[foo_node].map(&:text)
    assert_equal [
      '# method bar preceding',
      '# method bar sparse',
      '# method bar decorating'
    ], associations[bar_node].map(&:text)
    assert_equal [
      '# expression preceding'
    ], associations[expr_node].map(&:text)
    assert_equal [
      '# 1 decorating'
    ], associations[one_node].map(&:text)
  end

  # The bug below is fixed by using associate_locations
  def test_associate_dupe_statement
    ast, associations = associate(<<-END)
class Foo
  def bar
    f1 # comment on 1st call to f1
    f2
    f1 # comment on 2nd call to f1
  end
end
    END

    _klass_node        = ast
    method_node        = ast.children[2]
    body               = method_node.children[2]
    f1_1_node          = body.children[0]
    f1_2_node          = body.children[2]

    assert_equal 1, associations.size
    assert_equal ['# comment on 1st call to f1', '# comment on 2nd call to f1'],
                 associations[f1_1_node].map(&:text)
    assert_equal ['# comment on 1st call to f1', '# comment on 2nd call to f1'],
                 associations[f1_2_node].map(&:text)
  end

  def test_associate_locations
    ast, associations = associate_locations(<<-END)
#!/usr/bin/env ruby
# coding: utf-8
# class preceding
# another class preceding
class Foo # class keyword line
  # method foo preceding
  def foo
    puts 'foo'
  end # method foo decorating
  # method bar preceding
  def bar
    # expression preceding
    1 + # 1 decorating
      2
    # method bar sparse
  end # method bar decorating
  # class sparse
end # class decorating
    END

    klass_node      = ast
    klass_name_node = klass_node.children[0]
    foo_node        = klass_node.children[2].children[0] # def foo
    bar_node        = klass_node.children[2].children[1] # def bar
    expr_node       = bar_node.children[2] # 1 + 2
    one_node        = expr_node.children[0] # 1

    assert_equal 6, associations.size
    assert_equal [
      '# class preceding',
      '# another class preceding',
      '# class sparse',
      '# class decorating'
    ], associations[klass_node.loc].map(&:text)
    assert_equal [
      '# class keyword line'
    ], associations[klass_name_node.loc].map(&:text)
    assert_equal [
      '# method foo preceding',
      '# method foo decorating'
    ], associations[foo_node.loc].map(&:text)
    assert_equal [
      '# method bar preceding',
      '# method bar sparse',
      '# method bar decorating'
    ], associations[bar_node.loc].map(&:text)
    assert_equal [
      '# expression preceding'
    ], associations[expr_node.loc].map(&:text)
    assert_equal [
      '# 1 decorating'
    ], associations[one_node.loc].map(&:text)
  end

  def test_associate_locations_dupe_statement
    ast, associations = associate_locations(<<-END)
class Foo
  def bar
    f1 # comment on 1st call to f1
    f2
    f1 # comment on 2nd call to f1
  end
end
    END

    _klass_node        = ast
    method_node        = ast.children[2]
    body               = method_node.children[2]
    f1_1_node          = body.children[0]
    f1_2_node          = body.children[2]

    assert_equal 2, associations.size
    assert_equal ['# comment on 1st call to f1'],
                 associations[f1_1_node.loc].map(&:text)
    assert_equal ['# comment on 2nd call to f1'],
                 associations[f1_2_node.loc].map(&:text)
  end

  def test_associate_no_body
    ast, associations = associate(<<-END)
# foo
class Foo
end
    END

    assert_equal 1, associations.size
    assert_equal ['# foo'],
                 associations[ast].map(&:text)
  end

  def test_associate_empty_tree
    _ast, associations = associate("")
    assert_equal 0, associations.size
  end

  def test_associate_shebang_only
    _ast, associations = associate(<<-END)
#!ruby
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_frozen_string_literal
    _ast, associations = associate(<<-END)
# frozen_string_literal: true
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_frozen_string_literal_dash_star_dash
    _ast, associations = associate(<<-END)
# -*- frozen_string_literal: true -*-
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_frozen_string_literal_no_space_after_colon
    _ast, associations = associate(<<-END)
# frozen_string_literal:true
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_warn_indent
    _ast, associations = associate(<<-END)
# warn_indent: true
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_warn_indent_dash_star_dash
    _ast, associations = associate(<<-END)
# -*- warn_indent: true -*-
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_warn_past_scope
    _ast, associations = associate(<<-END)
# warn_past_scope: true
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_warn_past_scope_dash_star_dash
    _ast, associations = associate(<<-END)
# -*- warn_past_scope: true -*-
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_multiple
    _ast, associations = associate(<<-END)
# frozen_string_literal: true; warn_indent: true
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_multiple_dash_star_dash
    _ast, associations = associate(<<-END)
# -*- frozen_string_literal: true; warn_indent: true -*-
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_no_comments
    _ast, associations = associate(<<-END)
class Foo
end
    END

    assert_equal 0, associations.size
  end

  def test_associate_comments_after_root_node
    _ast, associations = associate(<<-END)
class Foo
end
# not associated
    END

    assert_equal 0, associations.size
  end


  def test_associate_stray_comment
    ast, associations = associate(<<-END)
def foo
  # foo
end
    END

    assert_equal 1, associations.size
    assert_equal ['# foo'],
                 associations[ast].map(&:text)
  end

  def test_associate___ENCODING__
    ast, associations = associate(<<-END)
# foo
__ENCODING__
    END

    assert_equal 1, associations.size
    assert_equal ['# foo'],
                 associations[ast].map(&:text)
  end

  def test_associate_inside_heredoc
    ast, associations = associate(<<-END)
<<x
\#{
  foo # bar
}
x
    END

    begin_node = ast.children[0]
    send_node  = begin_node.children[0]

    assert_equal 1, associations.size
    assert_equal ['# bar'],
                 associations[send_node].map(&:text)
  end
end
