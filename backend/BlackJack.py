import random
import pickle
from typing import List, Dict, Tuple

class BlackJackAgent:
    def __init__(self, epsilon: float = 1.0, epsilon_min: float = 0.1, epsilon_decay: float = 0.995, alpha: float = 0.5, gamma: float = 0.8, q_table_file: str = "q_table.pkl"):
        self.q_table = {}
        self.epsilon = epsilon  # Initial exploration rate
        self.epsilon_min = epsilon_min
        self.epsilon_decay = epsilon_decay
        self.alpha = alpha      # Learning rate
        self.gamma = gamma      # Discount factor
        self.q_table_file = q_table_file
        self.load_q_table()

    def get_action(self, state: Dict) -> str:
        if len(state["hand"]) == 2 and state["hand_value"] == 21:
            return 'BlackJack'


        if random.uniform(0, 1) < self.epsilon:
            return random.choice(['Hit', 'Stand'])
        return self.best_action(state)

    def best_action(self, state: Dict) -> str:
        state_key = self.state_to_key(state)
        if state_key not in self.q_table:
            self.q_table[state_key] = {'Hit': 0, 'Stand': 0}
        return max(self.q_table[state_key], key=self.q_table[state_key].get)

    def update_q_value(self, state: Dict, action: str, reward: float, next_state: Dict):
        state_key = self.state_to_key(state)
        next_state_key = self.state_to_key(next_state)

        if state_key not in self.q_table:
            self.q_table[state_key] = {'Hit': 0, 'Stand': 0}
        
        if action is None:
            return
        
        if next_state_key not in self.q_table:
            self.q_table[next_state_key] = {'Hit': 0, 'Stand': 0}

        best_next_action = self.best_action(next_state)
        self.q_table[state_key][action] += self.alpha * (
            reward + self.gamma * self.q_table[next_state_key][best_next_action] - self.q_table[state_key][action]
        )

    def save_q_table(self):
        with open(self.q_table_file, "wb") as f:
            pickle.dump(self.q_table, f)

    def load_q_table(self):
        try:
            with open(self.q_table_file, "rb") as f:
                self.q_table = pickle.load(f)
        except FileNotFoundError:
            self.q_table = {}

    def state_to_key(self, state: Dict) -> Tuple:
        """
        Convert a state dictionary to a hashable key.
        """
        return (
            tuple(sorted(state["hand"].items())),  # Hand composition
            state["soft"],                         # Soft/hard total
            state["hand_value"],                   # Total hand value
            state["dealer_card"]                   # Dealer's card
        )

    def decay_epsilon(self):
        """
        Decay epsilon for exploration-exploitation balance.
        """
        self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)

def calculate_hand_value(cards: List[Dict[str, str]]) -> Tuple[int, bool, Dict[str, int]]:
    """
    Calculate the value of a hand of cards, dynamically treating aces as 1 or 11.
    """
    value = 0
    aces = 0
    hand_composition = {str(i): 0 for i in range(2, 11)}
    hand_composition.update({'K': 0, 'Q': 0, 'J': 0, 'A': 0})

    for card in cards:
        hand_composition[card['number']] += 1
        if card['number'] in ['K', 'Q', 'J']:
            value += 10
        elif card['number'] == 'A':
            aces += 1
        else:
            value += int(card['number'])

    for _ in range(aces):
        if value + 11 <= 21:
            value += 11
        else:
            value += 1

    soft = aces > 0 and value <= 21
    return value, soft, hand_composition

def get_player_cards() -> List[Dict[str, str]]:
    while True:
        player_input = input("Enter your cards (e.g., 10, 6 or 'exit' to quit): ").strip()
        if player_input.lower() == 'exit':
            return []
        try:
            return [{'number': card} for card in player_input.split(", ")]
        except ValueError:
            print("Invalid input. Please enter the cards in the correct format.")
def main():
    agent = BlackJackAgent()

    responses_win=['Hopefully this enough for that monoi oil', 'All you do is win babayy', 'You are the king of the world', 'Another $187,417,237 to go for the house', 'These arbitrary wins have no value, you have transcended the futilities of commerce']
    responses_loss=["Dialysis isn't that bad....", "You're a loser, but you're MY loser", 'Quitters never prosper', "Go all in, you'll get the next game", "Well, you weren't going to use that money right?"]
    print("Training complete!")

    while True:
        player_cards = get_player_cards()
        if not player_cards:
            print("Saving progress and exiting the game.")
            agent.save_q_table()
            break

        dealer_card_input = input("Enter dealer's face-up card (e.g., K): ").strip()
        dealer_card = {'number': dealer_card_input}

        print(f"Your cards: {player_cards}")
        print(f"Dealer's card: {dealer_card}")

        player_hand_value, soft, hand_composition = calculate_hand_value(player_cards)

        # Handle BlackJack directly
        if player_hand_value == 21 and len(player_cards) == 2:
            print("BlackJack babyyy!!!")
            state = {
                "hand": hand_composition,
                "soft": soft,
                "hand_value": player_hand_value,
                "dealer_card": dealer_card['number']
            }
            reward = 15  # Assign high reward for BlackJack
            agent.update_q_value(state, None, reward, state)
            agent.decay_epsilon()
            continue  # Move to the next round

        # Otherwise, continue the normal game flow
        while True:
            print(f"Your hand value: {player_hand_value}")
            bust = False

            if player_hand_value > 21:
                print("You busted! Game over!")
                reward = -20  # Heavy penalty for busting
                bust = True
                break

            state = {
                "hand": hand_composition,
                "soft": soft,
                "hand_value": player_hand_value,
                "dealer_card": dealer_card['number']
            }
            action = agent.get_action(state)
            print(f"Agent decides to: {action}")

            if action == 'Stand':
                reward = 0  # Neutral for standing
                break
            elif action == 'Hit':
                new_card_input = input("Enter the card you drew (e.g., 7): ").strip()
                player_cards.append({'number': new_card_input})
                player_hand_value, soft, hand_composition = calculate_hand_value(player_cards)
                print(f"New card drawn: {new_card_input}")

        dealer_hand_value, _, _ = calculate_hand_value([dealer_card])
        print(f"Dealer's hand value: {dealer_hand_value}")

        if not bust:
            result = input("Enter the game result ('win', 'loss', or 'draw'): ").strip().lower()
            outcomes = {'win', 'loss', 'draw'}
            while result not in outcomes:
                result = input("Invalid result. Please enter 'win', 'loss', or 'draw': ").strip().lower()
            reward = {'win': 10, 'loss': -10, 'draw': 5}[result]

        agent.update_q_value(state, action, reward, state)
        agent.decay_epsilon()  # Decay exploration rate

if __name__ == "__main__":
    main()
