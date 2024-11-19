#!/bin/bash

session="CDN"

if tmux has-session -t $session 2>/dev/null; then
  echo "Chạy lại phiên tmux '$session'..."
  tmux kill-session -t $session
fi

tmux new-session -d -s $session

tmux rename-window -t $session:0 'cms'
tmux send-keys -t $session:0 'python3 cms.py' C-m

tmux new-window -t $session:1 -n 'data'
tmux send-keys -t $session:1 'bash data.sh' C-m

tmux new-window -t $session:2 -n 'monitor'
tmux send-keys -t $session:2 'python3 monitor.py' C-m

tmux new-window -t $session:3 -n 'database'
tmux send-keys -t $session:3 'python3 database.py' C-m
