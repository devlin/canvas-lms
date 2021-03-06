#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

module QuizzesHelper
  def render_score(score, precision=2)
    if score.nil?
      '_'
    else
      score.to_f.round(precision).to_s
    end
  end

  QuestionType = Struct.new(:question_type,
                          :entry_type,
                          :display_answers,
                          :answer_type,
                          :multiple_sets,
                          :unsupported
                         )

  def answer_type(question)
    return QuestionType.new unless question
    @answer_types_lookup ||= {
      "multiple_choice_question" => QuestionType.new(
        "multiple_choice_question",
        "radio",
        "multiple",
        "select_answer",
        false,
        false
      ),
      "true_false_question" => QuestionType.new(
        "true_false_question",
        "radio",
        "multiple",
        "select_answer",
        false,
        false
      ),
      "short_answer_question" => QuestionType.new(
        "short_answer_question",
        "text_box",
        "single",
        "select_answer",
        false,
        false
      ),
      "essay_question" => QuestionType.new(
        "essay_question",
        "textarea",
        "single",
        "text_answer",
        false,
        false
      ),
      "matching_question" => QuestionType.new(
        "matching_question",
        "matching",
        "multiple",
        "matching_answer",
        false,
        false
      ),
      "missing_word_question" => QuestionType.new(
        "missing_word_question",
        "select",
        "multiple",
        "select_answer",
        false,
        false
      ),
      "numerical_question" => QuestionType.new(
        "numerical_question",
        "numerical_text_box",
        "single",
        "numerical_answer",
        false,
        false
      ),
      "calculated_question" => QuestionType.new(
        "calculated_question",
        "numerical_text_box",
        "single",
        "numerical_answer",
        false,
        false
      ),
      "multiple_answers_question" => QuestionType.new(
        "multiple_answers_question",
        "checkbox",
        "multiple",
        "select_answer",
        false,
        false
      ),
      "fill_in_multiple_blanks_question" => QuestionType.new(
        "fill_in_multiple_blanks_question",
        "text_box",
        "multiple",
        "select_answer",
        true,
        false
      ),
      "multiple_dropdowns_question" => QuestionType.new(
        "multiple_dropdowns_question",
        "select",
        "none",
        "select_answer",
        true,
        false
      ),
      "other" =>  QuestionType.new(
        "text_only_question",
        "none",
        "none",
        "none",
        false,
        false
      )
    }
    res = @answer_types_lookup[question[:question_type]] || @answer_types_lookup["other"]
    if res.question_type == "text_only_question"
      res.unsupported = question[:question_type] != "text_only_question"
    end
    res
  end

  # Build the question-level comments. Lists in the order of :correct_comments, :incorrect_comments, :neutral_comments.
  # ==== Arguments
  # * <tt>user_answer</tt> - The user_answer hash.
  # * <tt>question</tt> - The question hash.
  def question_comment(user_answer, question)
    correct_text   = (hash_get(user_answer, :correct) == true) ? comment_get(question, :correct_comments) : nil
    incorrect_text = (hash_get(user_answer, :correct) == false) ? comment_get(question, :incorrect_comments) : nil
    neutral_text   = (hash_get(question, :neutral_comments).present?) ? comment_get(question, :neutral_comments) : nil

    text = []
    text << content_tag(:p, correct_text, {:class => 'correct_comments'}) if correct_text.present?
    text << content_tag(:p, incorrect_text, {:class => 'incorrect_comments'}) if incorrect_text.present?
    text << content_tag(:p, neutral_text, {:class => 'neutral_comments'}) if neutral_text.present?
    if text.empty?
      ''
    else
      content_tag(:div, text.join('').html_safe, {:class => 'quiz_comment'})
    end
  end

  def comment_get(hash, field)
    if html = hash_get(hash, "#{field}_html".to_sym)
      raw(html)
    else
      hash_get(hash, field)
    end
  end

  def fill_in_multiple_blanks_question(options)
    question = hash_get(options, :question)
    answers  = hash_get(options, :answers).dup
    answer_list = hash_get(options, :answer_list)
    res      = user_content hash_get(question, :question_text)
    readonly_markup = hash_get(options, :editable) ? ' />' : 'readonly="readonly" />'
    # If given answer list, insert the values into the text inputs for displaying user's answers.
    if answer_list && !answer_list.empty?
      index  = 0
      res.gsub %r{<input.*?name=['"](question_.*?)['"].*?/>} do |match|
        a = answer_list[index]
        index += 1
        #  Replace the {{question_BLAH}} template text with the user's answer text.
        match.sub(/\{\{question_.*?\}\}/, a.to_s).
          # Match on "/>" but only when at the end of the string and insert "readonly" if set to be readonly
          sub(/\/\>\Z/, readonly_markup)
      end
    else
      answers.delete_if { |k, v| !k.match /^question_#{hash_get(question, :id)}/ }
      answers.each { |k, v| res.sub! /\{\{#{k}\}\}/, v }
      res.gsub /\{\{question_[^}]+\}\}/, ""
    end
  end

  def multiple_dropdowns_question(options)
    question = hash_get(options, :question)
    answers  = hash_get(options, :answers)
    answer_list = hash_get(options, :answer_list)
    res      = user_content hash_get(question, :question_text)
    index  = 0
    res.gsub %r{<select.*?name=['"](question_.*?)['"].*?>.*?</select>} do |match|
      if answer_list && !answer_list.empty?
        a = answer_list[index]
        index += 1
      else
        a = hash_get(answers, $1)
      end
      match.sub(%r{(<option.*?value=['"]#{ERB::Util.h(a)}['"])}, '\\1 selected')
    end
  end

  def duration_in_minutes(duration_seconds)
    if duration_seconds < 60
      duration_minutes = 0
    else
      duration_minutes = (duration_seconds / 60).round
    end
    I18n.t("quizzes.helpers.duration_in_minutes",
      { :zero => "less than 1 minute",
        :one => "1 minute",
        :other => "%{count} minutes" },
      :count => duration_minutes)
  end

  def score_out_of_points_possible(score, points_possible, options={})
    options = {:precision => 2}.merge(options)
    score_html = \
      if options[:id] or options[:class] or options[:style] then
        content_tag('span',
          render_score(score, options[:precision]), 
          options.slice(:class, :id, :style))
      else
        render_score(score, options[:precision])
      end
    I18n.t("quizzes.helpers.score_out_of_points_possible", "%{score} out of %{points_possible}",
        :score => score_html,
        :points_possible => render_score(points_possible, options[:precision]))
  end
  
  def link_to_resume_poll
    link_to_take_quiz(resume_poll_message)
  end


  def resume_poll_message
    resume_survey_message || resume_quiz_message
  end

  def resume_survey_message
    t('#quizzes.links.resume_survey', 'Resume Survey') if @quiz.survey?
  end

  def resume_quiz_message
    t('#quizzes.links.resume_quiz', 'Resume Quiz')
  end

  def link_to_take_quiz(link_body)
    opts = {
      :class => poll_css_classes,
      'aria-controls' => poll_aria_controls,
      :id => "take_quiz_link"
    }
    opts['data-method'] = 'POST' unless @quiz.cant_go_back?
    link_to(
      link_body,
      take_quiz_url,
      opts
    )
  end

  def poll_css_classes
    'element_toggler' if @quiz.cant_go_back?
  end

  def poll_aria_controls
    'js-sequential-warning-dialogue' if @quiz.cant_go_back?
  end

  def take_quiz_url
    polymorphic_path(
      [@context,@quiz,:take],
      :user_id => @current_user && @current_user.id
    )
  end

  def link_to_take_or_retake_poll
    if @submission && !@submission.settings_only?
      link_to_retake_poll
    else
      link_to_take_poll
    end
  end

  def link_to_retake_poll
    link_to_take_quiz(take_poll_again_message)
  end

  def take_poll_again_message
    @quiz.survey? ?
      t('#quizzes.links.take_the_survey_again', 'Take the Survey Again') :
      t('#quizzes.links.take_the_quiz_again', 'Take the Quiz Again')
  end

  def link_to_take_poll
    link_to_take_quiz(take_poll_message)
  end

  def take_poll_message
    @quiz.survey? ?
      t('#quizzes.links.take_the_survey', 'Take the Survey') :
      t('#quizzes.links.take_the_quiz', 'Take the Quiz')
  end

end
