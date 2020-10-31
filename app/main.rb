# TeenyTiny DragonRuby MiniGameJam SimpleSample
# This is a simple sample game that takes 20 seconds to win (or lose).

SMALL_SHAPE_SIZE = 200
LARGE_SHAPE_SIZE = 300
VIEW_WIDTH = $args.grid.w
VIEW_HEIGHT = $args.grid.h
H_CENTRE = VIEW_WIDTH / 2
V_CENTRE = VIEW_HEIGHT / 2
WIN_SCORE = 10
MAX_TIME = 20 # SECONDS
SHORT_PAUSE = 30 # <-- ticks. 60 = 1 SECOND

def tick(args)
  return if SMALL_SHAPE_SIZE == 5

  # draw game components to the screen
  render_game(args)

  # check status to see what's happening
  # and act accordingly
  case args.state.status
  when :in_progress
    # the game is afoot
    inputs_game(args)
    calc_game(args)
  when :won_challenge
    # won a point
    calc_game(args)
    calc_won_challenge(args)
  when :lost_challenge
    # game is about to be over
    calc_game(args)
    calc_lost_challenge(args)
  when :lost_game, :won_game
    # game over
    render_game_over(args)
    inputs_game_over(args)
  else
    # it's the very start of the game. Set it up!
    defaults(args)
  end
end

# runs one time when the game loads
# and takes care of things that need to be done
# one time only
def defaults(args)
  # status tracks the state of the game
  args.state.status = :in_progress # or :lost_game or :won_game
  args.state.game_timer = MAX_TIME * 60 # game lasts 20 seconds
  args.state.score = 0

  # the basic shape types seen in the game
  args.state.shape_types = [
    'square',
    'circle',
    'hexagon',
    'diamond',
    'triangle',
    'octagon',
    'ellipse'
  ]

  # colours used in the game stored with their names
  args.state.colours ||= {
    black: [0, 0, 0],
    red: [255, 0, 0],
    green: [0, 255, 0],
    blue: [0, 0, 255],
    yellow: [255, 255, 0],
    orange: [255, 127, 0],
    purple: [127, 0, 127],
    white: [255, 255, 255]
  }

  # set up the first challenge
  prepare_challenge(args)
end

# causes a short pause and wipes the slate clean
def prepare_challenge(args)
  args.state.wait_after_answer = SHORT_PAUSE

  # wipe memory
  args.state.shapes = []
  args.state.labels = []

  # set up the challenge
  make_challenge(args)
end

# makes shapes and the clue
def make_challenge(args)
  # we need random colours and shapes
  colour_keys = args.state.colours.keys.shuffle!
  args.state.shape_types.shuffle!

  # now make three random coloured shapes
  args.state.shapes = 3.times.map do |i|
    {
      colour_name: colour_keys[i].to_s,
      colour_letters: (colour_keys[i].to_s[0, 1] + colour_keys[i].to_s[-1, 1]).capitalize,
      rgb_colour: args.state.colours[colour_keys[i]],
      shape_type: args.state.shape_types[i],
      x: 240 + (300 * i),
      y: 100,
      w: SMALL_SHAPE_SIZE,
      h: SMALL_SHAPE_SIZE,
      path: "sprites/#{args.state.shape_types[i]}.png",
      r: args.state.colours[colour_keys[i]][0],
      g: args.state.colours[colour_keys[i]][1],
      b: args.state.colours[colour_keys[i]][2]
    }
  end

  # and some labels to help colour-blind players
  args.state.hint_letters = args.state.shapes.map do |shape|
    string_w = ($gtk.calcstringbox(shape[:colour_name].capitalize, 0, 'fonts/font.ttf')[0] / 2)
    {
      x: shape.x + (SMALL_SHAPE_SIZE / 2) - string_w,
      y: shape.y - 20,
      text: shape[:colour_name].capitalize
    }
  end

  # shuffle the shapes
  args.state.shapes.shuffle!

  # the correct answer will be the first shape
  args.state.correct_answer = args.state.shapes[0]

  # the incorrect answer will be she second shape
  args.state.incorrect_answer = args.state.shapes[1].dup
  args.state.shapes << args.state.incorrect_answer

  # change location & size of the misleading shape
  args.state.incorrect_answer.merge!(
    {
      x: H_CENTRE - LARGE_SHAPE_SIZE / 2,
      y: 350,
      w: LARGE_SHAPE_SIZE,
      h: LARGE_SHAPE_SIZE
    }
  )

  # make the text clue
  text_colour = high_contrast(args.state.incorrect_answer[:rgb_colour])
  args.state.clue = "#{args.state.correct_answer[:colour_name]} #{args.state.correct_answer[:shape_type]}"
  args.state.labels << {
    x: H_CENTRE - ($gtk.calcstringbox('Click the', 0, 'fonts/font.ttf')[0] / 2),
    y: 520,
    text: 'Click the',
    r: text_colour[0],
    g: text_colour[1],
    b: text_colour[2]
  }
  args.state.labels << {
    x: H_CENTRE - ($gtk.calcstringbox(args.state.clue, 0, 'fonts/font.ttf')[0] / 2),
    y: 500,
    text: args.state.clue,
    r: text_colour[0],
    g: text_colour[1],
    b: text_colour[2]
  }
end

# draw the game on the screen
def render_game(args)
  args.outputs.labels  << [10, 710, "Time remaining: #{(args.state.game_timer / 60).to_int} seconds"]
  args.outputs.labels  << [10, 690, "Score: #{args.state.score} / #{WIN_SCORE}"]
  args.outputs.sprites << args.state.shapes

  # outputting these labels to primitives because we want to control the z order
  args.outputs.primitives  << args.state.labels
  args.outputs.primitives  << args.state.hint_letters
end

# do some calculations and check for a win
def calc_game(args)
  args.state.game_timer -= 1
  return unless args.state.game_timer.zero?

  args.state.status = if args.state.score >= WIN_SCORE
                        :won_game
                      else
                        :lost_game
                      end
end

# deal with user input while the game is running
def inputs_game(args)
  return unless args.inputs.mouse.click

  # check to see which shape was clicked
  3.times do |i|
    if args.inputs.mouse.inside_rect? args.state.shapes[i]
      if args.state.shapes[i] == args.state.correct_answer
        answered_correctly(args, args.state.shapes[i])
      else
        answered_incorrectly(args, args.state.shapes[i])
      end
    end
  end
end

def answered_correctly(args, clicked_shape)
  text_colour = high_contrast(clicked_shape[:rgb_colour])
  args.state.labels << [
    x: args.state.correct_answer.x + 10 + ($gtk.calcstringbox('Yeah!', 10, 'fonts/font.ttf')[0] / 2),
    y: 220,
    text: 'Yeah!',
    size_enum: 10,
    r: text_colour[0],
    g: text_colour[1],
    b: text_colour[2]
  ]
  args.state.score += 1
  args.state.status = :won_challenge
end

def answered_incorrectly(args, clicked_shape)
  text_colour = high_contrast(clicked_shape[:rgb_colour])
  args.state.labels << [
    x: clicked_shape.x - 10 + ($gtk.calcstringbox('Oh No!', 10, 'fonts/font.ttf')[0] / 2),
    y: 220,
    text: 'Oh No!',
    size_enum: 10,
    r: text_colour[0],
    g: text_colour[1],
    b: text_colour[2]
  ]
  args.state.status = :lost_challenge
end

# draw the game over overlay
def render_game_over(args)
  args.outputs.primitives << [0, 0, VIEW_WIDTH, VIEW_WIDTH, 255, 0, 0, 205].solid
  if args.state.status == :won_game
    message = 'Yay! You won the game!'
  elsif args.state.status == :lost_game
    message = 'Oh no! You lost the game!'
  end

  args.outputs.labels << {
    x: (VIEW_WIDTH / 2) - ($gtk.calcstringbox(message, 40, 'fonts/font.ttf')[0] / 2),
    y: (VIEW_HEIGHT / 2) + ($gtk.calcstringbox(message, 40, 'fonts/font.ttf')[1] / 2),
    text: message,
    size_enum: 40,
    r: 255,
    g: 255,
    b: 255
  }

  message = 'Click to play again'
  args.outputs.labels << {
    x: (VIEW_WIDTH / 2) - ($gtk.calcstringbox(message, 14, 'fonts/font.ttf')[0] / 2),
    y: (VIEW_HEIGHT / 2) - 80,
    text: message,
    size_enum: 14,
    r: 255,
    g: 255,
    b: 255
  }
end

# what happens after a successful answer
def calc_won_challenge(args)
  args.state.wait_after_answer -= 1
  return unless args.state.wait_after_answer <= 0

  args.state.status = :in_progress
  args.state.wait_after_answer = SHORT_PAUSE
  prepare_challenge(args)
end

# what happens after an wrong answer
def calc_lost_challenge(args)
  args.state.wait_after_answer -= 1
  return unless args.state.wait_after_answer <= 0

  args.state.status = :lost_game
end

# handle user input on the game over screen
def inputs_game_over(args)
  return unless args.inputs.mouse.click

  # start again
  defaults(args)
  args.state.status = :in_progress
end

# takes a background colour and returns either
# black or white depending on which
# is easier to read against the background
def high_contrast(colour)
  v = (colour[0] * 1.5 + colour[1] * 1.5 + colour[2]) / 3
  # the short way to do an if statement
  v > 127 ? [0, 0, 0] : [255, 255, 255]
end

# during development, this resets the game after a save
# seed serves up a fresh batch of random
$gtk.reset seed: Time.now.to_i
