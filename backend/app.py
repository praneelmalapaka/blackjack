import random
from flask import Flask, request, jsonify
from flask_cors import CORS
from BlackJack import BlackJackAgent, calculate_hand_value

app = Flask(__name__)
CORS(app)
agent = BlackJackAgent()

@app.route('/get_action', methods=['POST'])
def get_action():
    """
    Receives a JSON payload with the current state and returns the agent's decision.
    Expected JSON format:
      {
          "state": {
              "hand": { ... },
              "soft": true/false,
              "hand_value": int,
              "dealer_card": "K"  # for example
          }
      }
    """
    state = request.json.get('state')
    if not state:
        return jsonify({"error": "State data is required"}), 400

    action = agent.get_action(state)
    return jsonify({'action': action})

@app.route('/update_q_value', methods=['POST'])
def update_q_value():
    """
    Receives a JSON payload with state, action, reward, and next_state to update the Q-table.
    Expected JSON format:
      {
          "state": { ... },
          "action": "Hit" or "Stand",
          "reward": float,
          "next_state": { ... }
      }
    """
    data = request.json
    state = data.get('state')
    action = data.get('action')
    reward = data.get('reward')
    next_state = data.get('next_state')

    if state is None or reward is None or next_state is None:
        return jsonify({"error": "Missing required data: state, reward, or next_state"}), 400

    agent.update_q_value(state, action, reward, next_state)
    agent.decay_epsilon()
    return jsonify({"message": "Q-value updated successfully"})

@app.route('/save', methods=['GET'])
def save_q_table():
    """
    Saves the current Q-table to disk.
    """
    agent.save_q_table()
    return jsonify({"message": "Q-table saved successfully"})

@app.route('/load', methods=['GET'])
def load_q_table():
    """
    Loads the Q-table from disk.
    """
    agent.load_q_table()
    return jsonify({"message": "Q-table loaded successfully"})

@app.route('/calculate_hand', methods=['POST'])
def calculate_hand():
    try:
        content = request.get_json()
        cards = content['cards']
        dealer = content['dealer_card']

        hand_value, soft, composition = calculate_hand_value([{'number': c.strip().upper()} for c in cards])

        return jsonify({
            'hand_value': hand_value,
            'soft': soft,
            'hand': composition,
            'dealer_card': dealer.strip().upper()
        })
    except Exception as e:
        return jsonify({'error': f'Bad Request: {str(e)}'}), 400

@app.route('/get_result_response', methods=['POST'])
def get_result_response():
    data = request.get_json()
    result = data.get('result')

    responses_win = [
        'Hopefully this enough for that monoi oil',
        'All you do is win babayy',
        'You are the king of the world',
        'Another $187,417,237 to go for the house',
        'These arbitrary wins have no value, you have transcended the futilities of commerce'
    ]

    responses_loss = [
        "Dialysis isn't that bad....",
        "You're a loser, but you're MY loser",
        'Quitters never prosper',
        "Go all in, you'll get the next game",
        "Well, you weren't going to use that money right?"
    ]

    if result == "win":
        return jsonify({"message": random.choice(responses_win)})
    elif result in ["loss", "bust"]:
        return jsonify({"message": random.choice(responses_loss)})
    elif result == "draw":
        return jsonify({"message": "It's a draw!"})
    else:
        return jsonify({"error": "Invalid result type."}), 400

if __name__ == '__main__':
    # Run the Flask app on the default port (5000) in debug mode
    app.run(debug=True)
