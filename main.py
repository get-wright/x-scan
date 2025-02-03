#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import threading
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
import queue
import time

TOOL_INFO = {
    'semgrep': {
        'description': 'Static code analysis',
        'file_types': ['*.py', '*.js', '*.java', '*.go', '*.cpp', '*.c', '*.cs', '*.php', '*.rb', '*.ts']
    },
    'gitleaks': {
        'description': 'Secret scanner',
        'file_types': ['*']
    },
    'trivy': {
        'description': 'Vulnerability scanner',
        'file_types': ['Dockerfile*', '*.yaml', '*.yml', 'package*.json', 'requirements.txt']
    },
    'checkov': {
        'description': 'IaC scanner',
        'file_types': ['*.tf', '*.yaml', '*.yml', 'Dockerfile*', '.dockerignore', 'package.json']
    },
    'kubescape': {
        'description': 'Kubernetes scanner',
        'file_types': ['*.yaml', '*.yml']
    }
}

console = Console()

def show_tools():
    table = Table(title="Available Scanning Tools")
    table.add_column("Tool", style="cyan")
    table.add_column("Description", style="green")
    table.add_column("Supported Files", style="yellow")
    
    for tool, info in TOOL_INFO.items():
        table.add_row(
            tool,
            info['description'],
            ', '.join(info['file_types'])
        )
    
    console.print(table)

def stream_output(pipe, queue):
    """Helper function to stream output from a pipe to a queue"""
    try:
        with os.fdopen(os.dup(pipe.fileno()), 'rb') as f:
            for line in iter(f.readline, b''):
                try:
                    text = line.decode('utf-8', errors='replace').rstrip()
                    if text and not any(x in text for x in [
                        'Network', 'Creating', 'Created']):
                        queue.put(text)
                except Exception as e:
                    console.print(f"[red]Error decoding output: {str(e)}")
    finally:
        queue.put(None)

def run_tool(tool, verbose=False):
    try:
        os.makedirs('reports', exist_ok=True)
        
        # Print header
        if verbose:
            console.print(f"\n[yellow]═══════════ Running {tool} ═══════════")
        else:
            console.print(f"[yellow]Running {tool}...")
        
        process = subprocess.Popen(
            ['docker-compose', 'run', '--rm', tool],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0  # Use unbuffered mode
        )
        
        # Set up queues and threads
        stdout_queue = queue.Queue()
        stderr_queue = queue.Queue()
        
        stdout_thread = threading.Thread(target=stream_output, args=(process.stdout, stdout_queue))
        stderr_thread = threading.Thread(target=stream_output, args=(process.stderr, stderr_queue))
        
        stdout_thread.daemon = True
        stderr_thread.daemon = True
        
        stdout_thread.start()
        stderr_thread.start()
        
        while process.poll() is None or not stdout_queue.empty() or not stderr_queue.empty():
            # Process stdout
            try:
                line = stdout_queue.get_nowait()
                if line is not None and verbose:
                    console.print(f"  {line}")
            except queue.Empty:
                pass

            # Process stderr
            try:
                line = stderr_queue.get_nowait()
                if line is not None and verbose:
                    console.print(f"  [red]{line}")
            except queue.Empty:
                pass

            time.sleep(0.1)
        
        # Get final return code
        return_code = process.poll()
        
        if return_code != 0:
            if verbose:
                console.print(f"\n[red]Error: {tool} exited with code {return_code}")
            return False
        
        if verbose:
            console.print(f"\n[green]═══════════ {tool} completed ═══════════\n")
        return True
        
    except Exception as e:
        console.print(f"[red]Error running {tool}: {str(e)}")
        return False
    finally:
        # Ensure process is terminated
        if 'process' in locals():
            try:
                process.terminate()
            except:
                pass

def run_scans(tools, verbose=False):
    console.print(Panel(f"[yellow]Starting scans for: {', '.join(tools)}", title="Scan Start"))
    
    subprocess.run(
        ['docker-compose', 'down', '--remove-orphans'], 
        stdout=subprocess.DEVNULL, 
        stderr=subprocess.DEVNULL,
        check=False
    )
    
    results = []
    for tool in tools:
        success = run_tool(tool, verbose)
        results.append((tool, success))
    
    console.print("\n")
    summary_table = Table(title="Scan Results Summary")
    summary_table.add_column("Tool", style="cyan")
    summary_table.add_column("Status", justify="center")
    
    success_count = 0
    for tool, success in results:
        status = "[green]✓ Success" if success else "[red]✗ Failed"
        summary_table.add_row(tool, status)
        if success:
            success_count += 1
    
    console.print(summary_table)
    console.print(Panel(
        f"[{'green' if success_count == len(tools) else 'yellow'}]"
        f"Completed {success_count}/{len(tools)} scans successfully!\n"
        f"[yellow]Reports available in ./reports directory",
        title="Final Results"
    ))

def main():
    parser = argparse.ArgumentParser(description="X Scan - Automated Security Scanning Tool")
    parser.add_argument('--list', action='store_true', help='List available tools')
    parser.add_argument('--tools', type=str, help='Tools to run (comma-separated)')
    parser.add_argument('--all', action='store_true', help='Run all tools')
    parser.add_argument('--verbose', action='store_true', help='Show detailed output')
    
    args = parser.parse_args()
    
    if args.list:
        show_tools()
        return
    
    if args.all:
        tools = list(TOOL_INFO.keys())
    elif args.tools:
        tools = [t.strip() for t in args.tools.split(',')]
        invalid = [t for t in tools if t not in TOOL_INFO]
        if invalid:
            console.print(f"[red]Invalid tools: {', '.join(invalid)}")
            return
    else:
        console.print("[yellow]Please specify tools using --tools or --all")
        console.print("Use --list to see available tools")
        return
    
    run_scans(tools, args.verbose)

if __name__ == '__main__':
    main()