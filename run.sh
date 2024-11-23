#!/bin/bash

session="CDN"

if tmux has-session -t $session 2>/dev/null; then
  echo "Chạy lại phiên tmux '$session'..."
  tmux kill-session -t $session
fi

tmux new-session -d -s $session

tmux new-window -t $session:0 -n 'data'
tmux send-keys -t $session:0 'bash /home/ubuntu/CDN/data.sh' C-m

tmux new-window -t $session:1 -n 'monitor'
tmux send-keys -t $session:1 'python3 /home/ubuntu/CDN/monitor.py' C-m

tmux new-window -t $session:2 -n 'database'
tmux send-keys -t $session:2 'python3 /home/ubuntu/CDN/database.py' C-m
